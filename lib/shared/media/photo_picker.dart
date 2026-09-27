import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// IF-11: evidence photos are compressed client-side to ≤1 MB before upload.
const maxPhotoBytes = 1024 * 1024;

typedef PickedPhoto = ({Uint8List bytes, String fileName});

/// Picks a photo from [source] and re-encodes it (max 1280px, stepping JPEG
/// quality down from 85) until it fits [maxPhotoBytes]. Null if the user
/// cancels. Shared by fault reports and discrepancies.
Future<PickedPhoto?> pickCompressedPhoto(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    imageQuality: 90,
  );
  if (picked == null) return null;

  Future<Uint8List?> encode(int quality) =>
      FlutterImageCompress.compressWithFile(
        picked.path,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
      );

  var quality = 85;
  var bytes = await encode(quality) ?? await File(picked.path).readAsBytes();
  while (bytes.length > maxPhotoBytes && quality > 20) {
    quality -= 15;
    bytes = await encode(quality) ?? bytes;
  }
  return (bytes: bytes, fileName: picked.name);
}
