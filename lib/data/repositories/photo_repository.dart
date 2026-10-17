import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../features/admin/photos/photo_processor.dart';
import '../ids.dart';
import '../models.dart';

/// Where compressed bus photos are kept. The cache header is the point of the
/// design: a photo file is never overwritten (every upload gets a new name),
/// so a phone may keep it for a year and never ask for it again.
class PhotoCache {
  PhotoCache._();

  static const cacheControl = 'public, max-age=31536000, immutable';
  static const contentType = 'image/jpeg';
}

abstract class PhotoRepository {
  /// Uploads both sizes of [photo] for [busId] and returns what to store on
  /// the bus. [onProgress] reports 0..1 across both files.
  Future<BusPhoto> upload({
    required String busId,
    required ProcessedPhoto photo,
    void Function(double progress)? onProgress,
  });

  /// Best-effort removal of one photo's files, e.g. when a form is abandoned
  /// after uploading. The server also removes files nothing refers to.
  Future<void> discard(String busId, BusPhoto photo);
}

/// The few Storage operations the repository needs, so its logic can be
/// tested without a bucket.
abstract class StorageGateway {
  /// Stores [bytes] at [path] and returns the permanent download URL.
  Future<String> put(
    String path,
    Uint8List bytes, {
    required String contentType,
    required String cacheControl,
    void Function(double fraction)? onProgress,
  });

  Future<void> delete(String path);
}

class FirebaseStorageGateway implements StorageGateway {
  FirebaseStorageGateway([FirebaseStorage? storage])
      : _storage = storage ?? FirebaseStorage.instance;
  final FirebaseStorage _storage;

  @override
  Future<String> put(
    String path,
    Uint8List bytes, {
    required String contentType,
    required String cacheControl,
    void Function(double fraction)? onProgress,
  }) async {
    final ref = _storage.ref(path);
    final task = ref.putData(bytes,
        SettableMetadata(contentType: contentType, cacheControl: cacheControl));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

class StoragePhotoRepository implements PhotoRepository {
  StoragePhotoRepository(this._gateway);
  final StorageGateway _gateway;

  static String fullPath(String busId, String photoId) =>
      'buses/$busId/$photoId.jpg';
  static String thumbPath(String busId, String photoId) =>
      'buses/$busId/${photoId}_thumb.jpg';

  @override
  Future<BusPhoto> upload({
    required String busId,
    required ProcessedPhoto photo,
    void Function(double progress)? onProgress,
  }) async {
    // A fresh id every time: a file is never replaced, so it can be cached forever.
    final id = newId('ph');
    final total = photo.full.length + photo.thumb.length;
    var thumbDone = 0.0;
    var fullDone = 0.0;
    void report() => onProgress?.call(
        ((thumbDone * photo.thumb.length) + (fullDone * photo.full.length)) /
            total);

    // The thumbnail goes first: it is what lists show, and it is tiny.
    final thumbUrl = await _gateway.put(
      thumbPath(busId, id),
      photo.thumb,
      contentType: PhotoCache.contentType,
      cacheControl: PhotoCache.cacheControl,
      onProgress: (f) {
        thumbDone = f;
        report();
      },
    );
    try {
      final fullUrl = await _gateway.put(
        fullPath(busId, id),
        photo.full,
        contentType: PhotoCache.contentType,
        cacheControl: PhotoCache.cacheControl,
        onProgress: (f) {
          fullDone = f;
          report();
        },
      );
      onProgress?.call(1);
      return BusPhoto(id: id, fullUrl: fullUrl, thumbUrl: thumbUrl);
    } catch (_) {
      // Do not leave a thumbnail with no picture behind it.
      await _gateway.delete(thumbPath(busId, id)).catchError((Object _) {});
      rethrow;
    }
  }

  @override
  Future<void> discard(String busId, BusPhoto photo) async {
    await _gateway.delete(fullPath(busId, photo.id)).catchError((Object _) {});
    await _gateway.delete(thumbPath(busId, photo.id)).catchError((Object _) {});
  }
}

/// For demo mode and tests: keeps nothing, hands back stable fake URLs.
class MockPhotoRepository implements PhotoRepository {
  final List<String> uploaded = [];
  bool failNext = false;

  /// When set, uploads wait for it, so a test can look at the screen mid-upload.
  Completer<void>? hold;

  @override
  Future<BusPhoto> upload({
    required String busId,
    required ProcessedPhoto photo,
    void Function(double progress)? onProgress,
  }) async {
    if (hold != null) await hold!.future;
    if (failNext) {
      failNext = false;
      throw Exception('upload failed');
    }
    final id = newId('ph');
    onProgress?.call(1);
    uploaded.add(id);
    return BusPhoto(
      id: id,
      fullUrl: 'https://photos.invalid/buses/$busId/$id.jpg',
      thumbUrl: 'https://photos.invalid/buses/$busId/${id}_thumb.jpg',
    );
  }

  @override
  Future<void> discard(String busId, BusPhoto photo) async =>
      uploaded.remove(photo.id);
}
