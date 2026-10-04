import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Compresses an image file client-side to <= 1MB (IF-11) using iterative
/// quality reduction.
Future<Uint8List> compressImageUnderLimit(
  String path, {
  int maxBytes = 1024 * 1024,
}) async {
  var quality = 85;
  Uint8List result =
      await FlutterImageCompress.compressWithFile(
        path,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
      ) ??
      await File(path).readAsBytes();

  while (result.length > maxBytes && quality > 20) {
    quality -= 15;
    result =
        await FlutterImageCompress.compressWithFile(
          path,
          quality: quality,
          minWidth: 1280,
          minHeight: 1280,
        ) ??
        result;
  }
  return result;
}
