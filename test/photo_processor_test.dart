import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:charter_booking_ui/features/admin/photos/photo_processor.dart';

/// A noisy picture, like a real photo: smooth gradients plus grain, so it
/// does not compress to nothing the way a flat colour would.
Uint8List photo(int w, int h,
    {int seed = 1, bool withExif = false, int? orientation}) {
  final rnd = Random(seed);
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final base = (x * 255 ~/ w + y * 255 ~/ h) ~/ 2;
      final noise = rnd.nextInt(40) - 20;
      image.setPixelRgb(
          x,
          y,
          (base + noise).clamp(0, 255),
          (255 - base + noise).clamp(0, 255),
          (base ~/ 2 + noise).clamp(0, 255));
    }
  }
  if (withExif) {
    image.exif.imageIfd.data[0x010F] = img.IfdValueAscii('TestCam'); // Make
    image.exif.gpsIfd.data[0x0001] = img.IfdValueAscii('N'); // GPSLatitudeRef
    image.exif.gpsIfd.data[0x0002] = img.IfdValueRational(19, 1); // GPSLatitude
    if (orientation != null) image.exif.imageIfd.orientation = orientation;
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

({int w, int h}) size(Uint8List bytes) {
  final d = img.decodeJpg(bytes)!;
  return (w: d.width, h: d.height);
}

void main() {
  const processor = ImagePackagePhotoProcessor();

  test(
      'a large landscape photo comes out at 1280 px wide with a 360 px thumbnail, both small',
      () async {
    final original = photo(3000, 2000);
    final out = await processor.process(original);

    expect(size(out.full), (w: 1280, h: 853));
    expect(size(out.thumb), (w: 360, h: 240));
    expect(out.full.length, lessThanOrEqualTo(300 * 1024));
    expect(out.thumb.length, lessThanOrEqualTo(40 * 1024));
    expect(out.full.length, lessThan(original.length ~/ 3),
        reason: 'compression must really shrink it');
  });

  test('a portrait photo is limited by its height', () async {
    final out = await processor.process(photo(2000, 3000));
    expect(size(out.full), (w: 853, h: 1280));
    expect(size(out.thumb), (w: 240, h: 360));
  });

  test('a small photo is never enlarged', () async {
    final out = await processor.process(photo(600, 400));
    expect(size(out.full), (w: 600, h: 400));
    expect(size(out.thumb), (w: 360, h: 240));
  });

  test('metadata, including the GPS position, is removed', () async {
    final original = photo(1600, 1200, withExif: true);
    expect(img.decodeJpg(original)!.exif.gpsIfd.isEmpty, isFalse,
        reason: 'the test photo really carries a location');

    final out = await processor.process(original);
    for (final bytes in [out.full, out.thumb]) {
      final decoded = img.decodeJpg(bytes)!;
      expect(decoded.exif.gpsIfd.isEmpty, isTrue);
      expect(decoded.exif.imageIfd.isEmpty, isTrue);
    }
  });

  test("the camera's rotation is applied, not just recorded", () async {
    // Orientation 6 means "rotate 90° clockwise to display", so a 1600x1200 file shows as 1200x1600.
    final out = await processor
        .process(photo(1600, 1200, withExif: true, orientation: 6));
    final full = size(out.full);
    expect(full.h, greaterThan(full.w));
    expect(full.h, 1280);
  });

  test(
      'very detailed photos are squeezed under the size target by lowering quality',
      () async {
    final out = await processor.process(photo(4000, 3000, seed: 7));
    expect(out.full.length, lessThanOrEqualTo(300 * 1024));
  });

  test('a PNG is accepted and comes out as JPEG', () async {
    final png =
        Uint8List.fromList(img.encodePng(img.decodeJpg(photo(800, 600))!));
    final out = await processor.process(png);
    expect(out.full.sublist(0, 2), [0xFF, 0xD8]);
    expect(out.thumb.sublist(0, 2), [0xFF, 0xD8]);
  });

  test('things that are not photos are refused in plain words', () async {
    await expectLater(
        processor.process(Uint8List(0)),
        throwsA(isA<PhotoException>()
            .having((e) => e.message, 'm', contains('empty'))));
    await expectLater(
      processor.process(Uint8List.fromList(List.generate(500, (i) => i % 256))),
      throwsA(isA<PhotoException>()
          .having((e) => e.message, 'm', contains("couldn't read"))),
    );
    await expectLater(
      const ImagePackagePhotoProcessor(maxInputBytes: 1000)
          .process(photo(800, 600)),
      throwsA(isA<PhotoException>()
          .having((e) => e.message, 'm', contains('too large'))),
    );
  });

  test('every result is a real JPEG', () async {
    final out = await processor.process(photo(1500, 1000));
    expect(img.decodeJpg(out.full), isNotNull);
    expect(img.decodeJpg(out.thumb), isNotNull);
  });
}
