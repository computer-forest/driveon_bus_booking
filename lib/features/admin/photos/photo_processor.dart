import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A picture shrunk for upload, in the two sizes the app uses.
class ProcessedPhoto {
  const ProcessedPhoto({required this.full, required this.thumb});

  /// About 1280 px on the long side, for the bus page.
  final Uint8List full;

  /// About 360 px on the long side, for lists.
  final Uint8List thumb;
}

/// Thrown when a file cannot be used as a bus photo. [message] is already
/// worded for the person adding it.
class PhotoException implements Exception {
  const PhotoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Shrinks a picked picture before it is uploaded. This runs on the staff
/// member's phone, so no server-side resizing has to be paid for, and the
/// customer's phone only ever downloads the small versions.
abstract class PhotoProcessor {
  Future<ProcessedPhoto> process(Uint8List original);
}

/// Pure Dart, run in a background isolate so the screen does not freeze on a
/// 12-megapixel photo. It applies the camera's rotation and then drops all
/// metadata, which removes the GPS position a phone embeds in every photo.
class ImagePackagePhotoProcessor implements PhotoProcessor {
  const ImagePackagePhotoProcessor({
    this.fullSide = 1280,
    this.thumbSide = 360,
    this.fullQuality = 80,
    this.thumbQuality = 70,
    this.fullMaxBytes = 300 * 1024,
    this.fullHardMaxBytes = 600 * 1024,
    this.thumbMaxBytes = 40 * 1024,
    this.maxInputBytes = 25 * 1024 * 1024,
  });

  final int fullSide;
  final int thumbSide;
  final int fullQuality;
  final int thumbQuality;

  /// Quality is lowered until the picture is at most this big, down to
  /// [fullHardMaxBytes] as the limit it must never exceed.
  final int fullMaxBytes;
  final int fullHardMaxBytes;
  final int thumbMaxBytes;

  /// Refuse absurdly large files before trying to decode them.
  final int maxInputBytes;

  @override
  Future<ProcessedPhoto> process(Uint8List original) async {
    if (original.isEmpty) {
      throw const PhotoException("That file is empty. Choose a different photo.");
    }
    if (original.length > maxInputBytes) {
      throw const PhotoException(
          'That photo is too large. Choose one under 25 MB.');
    }
    final settings = this;
    try {
      return await Isolate.run(() => _process(original, settings));
    } on PhotoException {
      rethrow;
    } catch (_) {
      throw const PhotoException(
          "We couldn't read that photo. Choose a JPEG or PNG picture.");
    }
  }
}

ProcessedPhoto _process(Uint8List original, ImagePackagePhotoProcessor s) {
  final decoded = img.decodeImage(original);
  if (decoded == null) {
    throw const PhotoException(
        "We couldn't read that photo. Choose a JPEG or PNG picture.");
  }
  // Turn the picture the right way up, then forget the metadata.
  final upright = img.bakeOrientation(decoded);
  upright.exif.clear();

  final full = _encode(
      upright, s.fullSide, s.fullQuality, s.fullMaxBytes, s.fullHardMaxBytes);
  final thumb = _encode(upright, s.thumbSide, s.thumbQuality, s.thumbMaxBytes,
      s.thumbMaxBytes * 2);
  return ProcessedPhoto(full: full, thumb: thumb);
}

/// Scales so the long side is [side] (never enlarging), encodes as JPEG, and
/// lowers the quality in steps until it is at most [target] bytes, or as
/// small as it will go if it cannot get there. Throws if even the lowest
/// quality stays over [hardMax].
Uint8List _encode(
    img.Image source, int side, int quality, int target, int hardMax) {
  final longest = source.width > source.height ? source.width : source.height;
  final scaled = longest <= side
      ? source
      : img.copyResize(
          source,
          width: source.width >= source.height ? side : null,
          height: source.height > source.width ? side : null,
          interpolation: img.Interpolation.average,
        );
  Uint8List best = Uint8List(0);
  for (var q = quality; q >= 40; q -= 10) {
    best = Uint8List.fromList(img.encodeJpg(scaled, quality: q));
    if (best.length <= target) return best;
  }
  if (best.length > hardMax) {
    throw const PhotoException(
        'That photo is too detailed to shrink. Try a different one.');
  }
  return best;
}
