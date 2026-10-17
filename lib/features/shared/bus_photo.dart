import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';

/// The phone's own copy of bus photos. Files are immutable and served with a
/// one-year cache header, so once a picture has been seen it is never
/// downloaded again; this just bounds how much space they may take.
class BusPhotoCache {
  BusPhotoCache._();

  static const _key = 'busPhotos';

  /// Created on first use, so tests that never show a real photo never touch
  /// the disk cache.
  static final CacheManager instance = CacheManager(
    Config(_key,
        stalePeriod: const Duration(days: 60), maxNrOfCacheObjects: 200),
  );
}

/// What to draw for one picture. A provider so tests can swap in a plain box
/// instead of making network and disk requests.
typedef BusImageBuilder = Widget Function(String url,
    {required double? decodeWidth, required BoxFit fit});

final busImageBuilderProvider =
    Provider<BusImageBuilder>((ref) => cachedBusImage);

/// Warms a picture into the cache. A provider so tests need not hit the network.
final busPrecacheProvider =
    Provider<void Function(BuildContext, String)>((ref) => precacheBusPhoto);

Widget cachedBusImage(String url,
    {required double? decodeWidth, required BoxFit fit}) {
  return CachedNetworkImage(
    imageUrl: url,
    cacheManager: BusPhotoCache.instance,
    fit: fit,
    // Decode at the size it is shown, not the size it was stored: far less memory.
    memCacheWidth: decodeWidth?.round(),
    fadeInDuration: const Duration(milliseconds: 150),
    fadeOutDuration: Duration.zero,
    placeholder: (_, __) => const _Placeholder(),
    errorWidget: (_, __, ___) => const _Placeholder(),
  );
}

/// Starts downloading [url] into the phone's cache so it is ready when shown.
/// Never throws: a failed warm-up just means it loads when it is needed.
void precacheBusPhoto(BuildContext context, String url) {
  precacheImage(
          CachedNetworkImageProvider(url, cacheManager: BusPhotoCache.instance),
          context)
      .catchError((Object _) {});
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: AppColors.surface,
        child: Center(
            child: Icon(Icons.directions_bus_filled_rounded,
                size: 40, color: AppColors.textTertiary)),
      );
}

/// A bus picture, or a neutral bus icon when there is none or it will not load.
/// Lists pass the thumbnail URL and the bus page passes the full one.
class BusPhotoView extends ConsumerWidget {
  const BusPhotoView(
      {super.key,
      required this.url,
      this.fit = BoxFit.cover,
      this.decodeWidth});

  final String? url;
  final BoxFit fit;

  /// Logical width it will be drawn at; used to decode no more than needed.
  final double? decodeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = url;
    if (u == null || u.isEmpty) return const _Placeholder();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ref.watch(busImageBuilderProvider)(u,
        decodeWidth: decodeWidth == null ? null : decodeWidth! * dpr, fit: fit);
  }
}
