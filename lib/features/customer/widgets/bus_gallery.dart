import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../data/models.dart';
import '../../shared/bus_photo.dart';

/// The swipeable pictures at the top of the bus page. Only the page on screen
/// is fetched; the next one is fetched as soon as the customer starts looking
/// at this one, so swiping feels instant without downloading what is never
/// looked at. With no photos it shows a single neutral bus picture.
class BusGallery extends ConsumerStatefulWidget {
  const BusGallery({super.key, required this.photos, this.height = 180});

  final List<BusPhoto> photos;
  final double height;

  @override
  ConsumerState<BusGallery> createState() => _BusGalleryState();
}

class _BusGalleryState extends ConsumerState<BusGallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _warmNext(int page) {
    final next = page + 1;
    if (next >= widget.photos.length) return;
    ref.read(busPrecacheProvider)(context, widget.photos[next].fullUrl);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return ClipRRect(
      borderRadius: AppRadius.containerRadius,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: photos.isEmpty ? 1 : photos.length,
              onPageChanged: (i) {
                setState(() => _page = i);
                _warmNext(i);
              },
              itemBuilder: (context, i) => BusPhotoView(
                key: Key(photos.isEmpty ? 'bus-photo-empty' : 'bus-photo-$i'),
                url: photos.isEmpty ? null : photos[i].fullUrl,
                decodeWidth: MediaQuery.sizeOf(context).width,
              ),
            ),
            if (photos.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
