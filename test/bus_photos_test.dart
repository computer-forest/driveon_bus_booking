import 'dart:async';
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:charter_booking_ui/core/theme/app_theme.dart';
import 'package:charter_booking_ui/core/widgets/app_buttons.dart';
import 'package:charter_booking_ui/data/mock_data.dart';
import 'package:charter_booking_ui/data/models.dart';
import 'package:charter_booking_ui/data/providers.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_codec.dart';
import 'package:charter_booking_ui/data/repositories/firestore/firestore_repositories.dart';
import 'package:charter_booking_ui/data/repositories/mock_repositories.dart';
import 'package:charter_booking_ui/data/repositories/photo_repository.dart';
import 'package:charter_booking_ui/features/admin/photos/photo_picker.dart';
import 'package:charter_booking_ui/features/admin/photos/photo_processor.dart';
import 'package:charter_booking_ui/features/admin/screens/bus_form_screen.dart';
import 'package:charter_booking_ui/features/customer/widgets/bus_gallery.dart';
import 'package:charter_booking_ui/features/customer/widgets/bus_result_card.dart';
import 'package:charter_booking_ui/features/shared/bus_photo.dart';

// ---- fakes -----------------------------------------------------------------

class FakeGateway implements StorageGateway {
  final Map<String,
      ({Uint8List bytes, String contentType, String cacheControl})> files = {};
  final List<String> deleted = [];
  String? failOnPath;

  @override
  Future<String> put(String path, Uint8List bytes,
      {required String contentType,
      required String cacheControl,
      void Function(double)? onProgress}) async {
    if (failOnPath != null && path.contains(failOnPath!)) {
      throw Exception('boom');
    }
    onProgress?.call(0.5);
    files[path] =
        (bytes: bytes, contentType: contentType, cacheControl: cacheControl);
    onProgress?.call(1);
    return 'https://files.invalid/$path';
  }

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    files.remove(path);
  }
}

class FakePicker implements PhotoPicker {
  FakePicker(this.result);
  Uint8List? result;
  PhotoSource? lastSource;
  bool throwOnPick = false;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    lastSource = source;
    if (throwOnPick) throw Exception('no permission');
    return result;
  }
}

class FakeProcessor implements PhotoProcessor {
  FakeProcessor();
  Object? error;
  int calls = 0;

  @override
  Future<ProcessedPhoto> process(Uint8List original) async {
    calls++;
    final e = error;
    if (e != null) throw e;
    return ProcessedPhoto(
        full: Uint8List.fromList([1, 2, 3, 4]),
        thumb: Uint8List.fromList([1, 2]));
  }
}

Widget plainImage(String url,
        {required double? decodeWidth, required BoxFit fit}) =>
    ColoredBox(color: Colors.teal, child: Text(url, key: Key('img:$url')));

BusPhoto photo(String id) => BusPhoto(
    id: id,
    fullUrl: 'https://x/$id.jpg',
    thumbUrl: 'https://x/${id}_thumb.jpg');

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('uploading', () {
    late FakeGateway gateway;
    late StoragePhotoRepository repo;
    final processed =
        ProcessedPhoto(full: Uint8List(300), thumb: Uint8List(30));

    setUp(() {
      gateway = FakeGateway();
      repo = StoragePhotoRepository(gateway);
    });

    test(
        'both sizes are stored under the bus with a JPEG type and the one-year immutable cache header',
        () async {
      final result = await repo.upload(busId: 'bus-1', photo: processed);

      expect(
          gateway.files.keys,
          containsAll([
            'buses/bus-1/${result.id}.jpg',
            'buses/bus-1/${result.id}_thumb.jpg'
          ]));
      for (final f in gateway.files.values) {
        expect(f.contentType, 'image/jpeg');
        expect(f.cacheControl, 'public, max-age=31536000, immutable');
      }
      expect(
          result.fullUrl, 'https://files.invalid/buses/bus-1/${result.id}.jpg');
      expect(result.thumbUrl,
          'https://files.invalid/buses/bus-1/${result.id}_thumb.jpg');
    });

    test('every upload gets a new name, so a stored file is never replaced',
        () async {
      final a = await repo.upload(busId: 'bus-1', photo: processed);
      final b = await repo.upload(busId: 'bus-1', photo: processed);
      expect(a.id, isNot(b.id));
      expect(gateway.files.length, 4);
    });

    test('progress climbs from zero to one across both files', () async {
      final seen = <double>[];
      await repo.upload(busId: 'bus-1', photo: processed, onProgress: seen.add);
      expect(seen.last, 1);
      expect(seen.every((p) => p >= 0 && p <= 1), isTrue);
      expect(seen, [...seen]..sort(), reason: 'it never goes backwards');
    });

    test(
        'if the big picture fails, the thumbnail is not left behind and the error reaches the caller',
        () async {
      gateway.failOnPath = '.jpg';
      // fail only the full file: its path does not contain "_thumb"
      gateway.failOnPath = null;
      final failing = _FailFullGateway(gateway);
      await expectLater(
          StoragePhotoRepository(failing)
              .upload(busId: 'bus-1', photo: processed),
          throwsException);
      expect(gateway.files, isEmpty);
    });

    test('discarding removes both files', () async {
      final result = await repo.upload(busId: 'bus-1', photo: processed);
      await repo.discard('bus-1', result);
      expect(gateway.files, isEmpty);
    });
  });

  group('storing photos on the bus', () {
    test('photos round-trip through Firestore, in order', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreBusRepository(db, () => 'staff_1');
      final bus = BusRecord(
        id: 'bus-p',
        regNumber: 'MH-04-XX-0001',
        vendorId: 'ven-neeta',
        vendorName: 'Neeta',
        capacity: 20,
        seatType: 'Pushback seats',
        ac: true,
        baseCity: 'Thane',
        driverName: 'Unassigned',
        active: true,
        weeklyAvailability:
            List.filled(7, const DayAvailability(available: true)),
        photos: [photo('ph-1'), photo('ph-2')],
      );
      await repo.upsert(bus);
      final back = (await repo.watchAll().first).single;
      expect(back.photos, [photo('ph-1'), photo('ph-2')]);
      expect(back.cover, photo('ph-1'));
      expect(back.photoCount, 2);
    });

    test(
        'an older record that only had a photo count reads back with no photos',
        () {
      final bus = Codec.busFromMap('old',
          {'regNumber': 'X', 'photoCount': 4, 'weeklyAvailability': const []});
      expect(bus.photos, isEmpty);
      expect(bus.cover, isNull);
    });

    test('damaged photo entries are skipped, not a crash', () {
      final bus = Codec.busFromMap('x', {
        'weeklyAvailability': const [],
        'photos': [
          {'id': 'ok', 'full': 'https://a', 'thumb': 'https://b'},
          {'id': 'no-urls'},
          'junk',
          {'id': 'half', 'full': 'https://a'},
        ],
      });
      expect(bus.photos.map((p) => p.id), ['ok']);
    });

    test('the sample buses no longer claim photos they do not have', () {
      expect(MockData.buses.every((b) => b.photos.isEmpty), isTrue);
    });
  });

  group('bus form', () {
    late FakePicker picker;
    late FakeProcessor processor;
    late MockPhotoRepository photoRepo;
    late MockBackend backend;

    Future<void> openForm(WidgetTester tester, {BusRecord? bus}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      picker = FakePicker(Uint8List.fromList([1, 2, 3]));
      processor = FakeProcessor();
      photoRepo = MockPhotoRepository();
      backend = MockBackend();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          mockBackendProvider.overrideWithValue(backend),
          photoPickerProvider.overrideWithValue(picker),
          photoProcessorProvider.overrideWithValue(processor),
          photoRepositoryProvider.overrideWithValue(photoRepo),
          busImageBuilderProvider.overrideWithValue(plainImage),
        ],
        child:
            MaterialApp(theme: AppTheme.light, home: BusFormScreen(bus: bus)),
      ));
      await settle(tester);
    }

    Future<void> scrollToPhotos(WidgetTester tester) =>
        tester.scrollUntilVisible(find.byKey(const Key('add-photo')), 300,
            scrollable: find.byType(Scrollable).first);

    Future<void> addFromGallery(WidgetTester tester) async {
      await scrollToPhotos(tester);
      await tester.tap(find.byKey(const Key('add-photo')));
      await settle(tester);
      await tester.tap(find.text('Choose from gallery'));
      await settle(tester);
    }

    testWidgets(
        'with no photos it asks for one, and no longer pretends to hold four',
        (tester) async {
      await openForm(tester);
      await scrollToPhotos(tester);
      expect(find.textContaining('Add at least one photo'), findsOneWidget);
      expect(find.byKey(const Key('add-photo')), findsOneWidget);
    });

    testWidgets(
        'choosing from the gallery shrinks, uploads and shows the picture as the cover',
        (tester) async {
      await openForm(tester);
      await addFromGallery(tester);

      expect(picker.lastSource, PhotoSource.gallery);
      expect(processor.calls, 1);
      expect(photoRepo.uploaded, hasLength(1));
      expect(find.text('Cover'), findsOneWidget);
      expect(find.byKey(const Key('uploading-photo')), findsNothing);
    });

    testWidgets('the camera option is offered too', (tester) async {
      await openForm(tester);
      await scrollToPhotos(tester);
      await tester.tap(find.byKey(const Key('add-photo')));
      await settle(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);
      expect(picker.lastSource, PhotoSource.camera);
    });

    testWidgets('backing out of the picker adds nothing', (tester) async {
      await openForm(tester);
      picker.result = null;
      await addFromGallery(tester);
      expect(processor.calls, 0);
      expect(photoRepo.uploaded, isEmpty);
    });

    testWidgets(
        'a phone that refuses camera access says so instead of failing silently',
        (tester) async {
      await openForm(tester);
      picker.throwOnPick = true;
      await addFromGallery(tester);
      expect(find.textContaining("Couldn't open the gallery"), findsOneWidget);
    });

    testWidgets('at most four photos: the add slot disappears at four',
        (tester) async {
      await openForm(tester);
      for (var i = 0; i < 4; i++) {
        await addFromGallery(tester);
      }
      expect(photoRepo.uploaded, hasLength(4));
      expect(find.byKey(const Key('add-photo')), findsNothing);
    });

    testWidgets(
        'a photo that cannot be read shows the reason and can be dismissed',
        (tester) async {
      await openForm(tester);
      processor.error = const PhotoException(
          "We couldn't read that photo. Choose a JPEG or PNG picture.");
      await addFromGallery(tester);
      expect(find.textContaining("couldn't read that photo"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await settle(tester);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a failed upload can be retried and then succeeds',
        (tester) async {
      await openForm(tester);
      photoRepo.failNext = true;
      await addFromGallery(tester);
      expect(find.textContaining("Couldn't upload that photo"), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(photoRepo.uploaded, hasLength(1));
      expect(find.text('Cover'), findsOneWidget);
    });

    testWidgets(
        'removing a photo that was only just added deletes its files at once',
        (tester) async {
      await openForm(tester);
      await addFromGallery(tester);
      final id = photoRepo.uploaded.single;
      await tester.tap(find.byTooltip('Remove photo'));
      await settle(tester);
      expect(photoRepo.uploaded, isNot(contains(id)),
          reason: 'discarded from storage');
      expect(find.text('Cover'), findsNothing);
    });

    testWidgets('a second photo can be made the cover', (tester) async {
      await openForm(tester);
      await addFromGallery(tester);
      await addFromGallery(tester);
      expect(find.byTooltip('Make cover'), findsOneWidget);
      final firstId = photoRepo.uploaded.first;
      await tester.tap(find.byTooltip('Make cover'));
      await settle(tester);
      // the one that was first is now the other, so its tile offers "Make cover"
      expect(find.byTooltip('Make cover'), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
      expect(find.byKey(Key('photo-$firstId')), findsOneWidget);
    });

    testWidgets('abandoning the form after uploading deletes the unsaved files',
        (tester) async {
      await openForm(tester);
      await addFromGallery(tester);
      expect(photoRepo.uploaded, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(photoRepo.uploaded, isEmpty);
    });

    testWidgets('saving stores the photos on the bus, not a made-up count',
        (tester) async {
      final existing = MockData.buses.first;
      await openForm(tester, bus: existing);
      await addFromGallery(tester);
      final uploaded = photoRepo.uploaded.single;

      await tester.scrollUntilVisible(find.text('Save changes'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Save changes'));
      await settle(tester);

      final saved = backend.buses.items.firstWhere((b) => b.id == existing.id);
      expect(saved.photos.single.id, uploaded);
      expect(saved.photoCount, 1);
    });

    testWidgets(
        'Save is held back, and says why, while a photo is still uploading',
        (tester) async {
      final existing = MockData.buses.first;
      await openForm(tester, bus: existing);
      photoRepo.hold = Completer<void>();
      await scrollToPhotos(tester);
      await tester.tap(find.byKey(const Key('add-photo')));
      await settle(tester);
      await tester.tap(find.text('Choose from gallery'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.scrollUntilVisible(find.text('Uploading photos…'), 300,
          scrollable: find.byType(Scrollable).first);
      final button = tester.widget<PrimaryButton>(find.ancestor(
          of: find.text('Uploading photos…'),
          matching: find.byType(PrimaryButton)));
      expect(button.onPressed, isNull);

      photoRepo.hold!.complete();
      await settle(tester);
      expect(find.text('Save changes'), findsOneWidget);
    });
  });

  group('what customers see', () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          busImageBuilderProvider.overrideWithValue(plainImage),
          busPrecacheProvider.overrideWithValue((_, url) => precached.add(url)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
      ));
      await settle(tester);
    }

    setUp(precached.clear);

    BusRecord busWith(List<BusPhoto> photos) => BusRecord(
          id: 'b',
          regNumber: 'MH-04-AA-0001',
          vendorId: 'v',
          vendorName: 'V',
          capacity: 20,
          seatType: 'Pushback seats',
          ac: true,
          baseCity: 'Thane',
          driverName: 'D',
          active: true,
          weeklyAvailability:
              List.filled(7, const DayAvailability(available: true)),
          photos: photos,
        );

    testWidgets(
        'the results list shows the small thumbnail, never the full-size picture',
        (tester) async {
      await pump(
          tester,
          BusResultCard(
              bus: busWith([photo('ph-1'), photo('ph-2')]),
              windowLabel: '6 AM – 10 PM',
              onSelect: () {},
              onViewDetails: () {}));
      expect(find.byKey(const Key('bus-card-cover')), findsOneWidget);
      expect(find.byKey(const Key('img:https://x/ph-1_thumb.jpg')),
          findsOneWidget);
      expect(find.byKey(const Key('img:https://x/ph-1.jpg')), findsNothing);
    });

    testWidgets(
        'a bus with no photos shows the neutral bus picture, not empty slots',
        (tester) async {
      await pump(
          tester,
          BusResultCard(
              bus: busWith(const []),
              windowLabel: '6 AM – 10 PM',
              onSelect: () {},
              onViewDetails: () {}));
      expect(find.byKey(const Key('bus-card-cover')), findsNothing);
      expect(find.byIcon(Icons.ac_unit_rounded), findsOneWidget);
    });

    testWidgets(
        'the bus page gallery shows the full picture and swipes through them',
        (tester) async {
      await pump(tester,
          BusGallery(photos: [photo('ph-1'), photo('ph-2'), photo('ph-3')]));
      expect(find.byKey(const Key('img:https://x/ph-1.jpg')), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-250, 0));
      await settle(tester);
      expect(find.byKey(const Key('img:https://x/ph-2.jpg')), findsOneWidget);
    });

    testWidgets(
        'only the next picture is fetched ahead, and nothing is fetched twice for one view',
        (tester) async {
      await pump(tester,
          BusGallery(photos: [photo('ph-1'), photo('ph-2'), photo('ph-3')]));
      expect(precached, isEmpty,
          reason: 'nothing is fetched ahead until the customer starts swiping');
      await tester.drag(find.byType(PageView), const Offset(-250, 0));
      await settle(tester);
      expect(precached, ['https://x/ph-3.jpg']);
    });

    testWidgets('no photos: one neutral bus picture and no page dots',
        (tester) async {
      await pump(tester, const BusGallery(photos: []));
      expect(find.byKey(const Key('bus-photo-empty')), findsOneWidget);
      expect(find.byType(AnimatedContainer), findsNothing);
    });
  });
}

final precached = <String>[];

/// Fails only the large file, to prove the thumbnail is cleaned up.
class _FailFullGateway implements StorageGateway {
  _FailFullGateway(this.inner);
  final FakeGateway inner;

  @override
  Future<String> put(String path, Uint8List bytes,
      {required String contentType,
      required String cacheControl,
      void Function(double)? onProgress}) {
    if (!path.contains('_thumb')) throw Exception('network dropped');
    return inner.put(path, bytes,
        contentType: contentType,
        cacheControl: cacheControl,
        onProgress: onProgress);
  }

  @override
  Future<void> delete(String path) => inner.delete(path);
}
