import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models.dart';
import '../../../data/providers.dart';
import '../../shared/bus_photo.dart';
import 'photo_picker.dart';
import 'photo_processor.dart';

/// One upload that is in progress or has failed, shown in its own slot.
class _Pending {
  _Pending(this.bytes);
  final Uint8List bytes;
  double progress = 0;
  String? error;
}

/// The photo slots on the bus form: up to [BusRecord.maxPhotos], the first
/// being the cover. A picture is shrunk on this phone, uploaded, and only then
/// added to the list; nothing is attached to the bus until the form is saved.
class BusPhotoEditor extends ConsumerStatefulWidget {
  const BusPhotoEditor({
    super.key,
    required this.busId,
    required this.photos,
    required this.onChanged,
    required this.onBusyChanged,
    required this.onUploaded,
    required this.onDiscarded,
  });

  final String busId;
  final List<BusPhoto> photos;
  final ValueChanged<List<BusPhoto>> onChanged;

  /// True while any upload is running, so the form can hold off saving.
  final ValueChanged<bool> onBusyChanged;

  /// A new file now exists in storage; the form remembers it so an abandoned
  /// form can clean up.
  final ValueChanged<BusPhoto> onUploaded;

  /// A photo was removed. The form decides whether its files can be deleted
  /// at once (never saved) or must wait for the save (already on the bus).
  final ValueChanged<BusPhoto> onDiscarded;

  @override
  ConsumerState<BusPhotoEditor> createState() => _BusPhotoEditorState();
}

class _BusPhotoEditorState extends ConsumerState<BusPhotoEditor> {
  final List<_Pending> _pending = [];

  int get _used => widget.photos.length + _pending.length;
  bool get _busy => _pending.any((p) => p.error == null);

  void _setBusy() => widget.onBusyChanged(_busy);

  Future<void> _add() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    Uint8List? bytes;
    try {
      bytes = await ref.read(photoPickerProvider).pick(source);
    } catch (_) {
      _say(
          "Couldn't open the ${source == PhotoSource.camera ? 'camera' : 'gallery'}. Check the app's permissions in Settings.");
      return;
    }
    if (bytes == null || !mounted) return;
    final pending = _Pending(bytes);
    setState(() => _pending.add(pending));
    _setBusy();
    await _upload(pending);
  }

  Future<void> _upload(_Pending pending) async {
    setState(() {
      pending.error = null;
      pending.progress = 0;
    });
    _setBusy();
    try {
      final processed =
          await ref.read(photoProcessorProvider).process(pending.bytes);
      final photo = await ref.read(photoRepositoryProvider).upload(
            busId: widget.busId,
            photo: processed,
            onProgress: (p) {
              if (mounted) setState(() => pending.progress = p);
            },
          );
      if (!mounted) {
        // The form was closed meanwhile; the file would be orphaned.
        await ref.read(photoRepositoryProvider).discard(widget.busId, photo);
        return;
      }
      widget.onUploaded(photo);
      setState(() => _pending.remove(pending));
      widget.onChanged([...widget.photos, photo]);
    } on PhotoException catch (e) {
      if (mounted) setState(() => pending.error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => pending.error = "Couldn't upload that photo. Tap to try again.");
      }
    }
    if (mounted) _setBusy();
  }

  void _remove(BusPhoto photo) {
    widget.onChanged([...widget.photos]..remove(photo));
    widget.onDiscarded(photo);
  }

  void _makeCover(BusPhoto photo) {
    widget.onChanged([photo, ...widget.photos.where((p) => p != photo)]);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final slots = <Widget>[
      for (var i = 0; i < widget.photos.length; i++)
        _filled(widget.photos[i], isCover: i == 0),
      for (final p in _pending) _uploading(p),
      if (_used < BusRecord.maxPhotos) _addSlot(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
            spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: slots),
        for (final p in _pending)
          if (p.error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(p.error!,
                  style:
                      textTheme.labelMedium?.copyWith(color: AppColors.urgent)),
            ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          widget.photos.isEmpty && _pending.isEmpty
              ? 'Add at least one photo so customers can see the bus. The first photo is the cover.'
              : 'The first photo is the cover. Tap the star to make another one the cover.',
          style: textTheme.labelMedium,
        ),
      ],
    );
  }

  static const _size = 76.0;

  Widget _frame({required Widget child}) => ClipRRect(
        borderRadius: AppRadius.controlRadius,
        child: SizedBox(width: _size, height: _size, child: child),
      );

  Widget _addSlot() => InkWell(
        key: const Key('add-photo'),
        onTap: _add,
        borderRadius: AppRadius.controlRadius,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.controlRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(Icons.add_a_photo_outlined,
              size: 22, color: AppColors.textTertiary),
        ),
      );

  Widget _filled(BusPhoto photo, {required bool isCover}) {
    return Stack(
      key: Key('photo-${photo.id}'),
      children: [
        _frame(child: BusPhotoView(url: photo.thumbUrl, decodeWidth: _size)),
        Positioned(
          top: 2,
          right: 2,
          child:
              _badge(Icons.close_rounded, 'Remove photo', () => _remove(photo)),
        ),
        Positioned(
          bottom: 2,
          left: 2,
          child: isCover
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('Cover',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.onPrimary)),
                )
              : _badge(Icons.star_border_rounded, 'Make cover',
                  () => _makeCover(photo)),
        ),
      ],
    );
  }

  Widget _badge(IconData icon, String tooltip, VoidCallback onTap) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      );

  Widget _uploading(_Pending p) {
    final failed = p.error != null;
    return GestureDetector(
      key: const Key('uploading-photo'),
      onTap: failed ? () => _upload(p) : null,
      child: Stack(
        children: [
          _frame(
            child: Container(
              color: AppColors.surface,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: failed
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            size: 20, color: AppColors.urgent),
                        Text('Retry',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.urgent)),
                      ],
                    )
                  : CircularProgressIndicator(
                      value: p.progress == 0 ? null : p.progress,
                      strokeWidth: 3),
            ),
          ),
          if (failed)
            Positioned(
              top: 2,
              right: 2,
              child: _badge(Icons.close_rounded, 'Dismiss', () {
                setState(() => _pending.remove(p));
                _setBusy();
              }),
            ),
        ],
      ),
    );
  }
}
