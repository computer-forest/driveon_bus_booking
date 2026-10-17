import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Lets staff choose a picture. Behind an interface so tests need no camera.
abstract class PhotoPicker {
  /// The picture's bytes, or null if the person backed out.
  Future<Uint8List?> pick(PhotoSource source);
}

class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
      : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    // Ask the phone to hand over at most 2048 px at q90, so a 12-megapixel
    // photo is already cheap to decode when we shrink it properly.
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    return file?.readAsBytes();
  }
}
