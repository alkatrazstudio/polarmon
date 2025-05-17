// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/services.dart';

abstract class Storage {
  static const platform = MethodChannel('polarmon.alkatrazstudio.net/storage');

  static Future<String?> saveFile(String initialFilename, String mime, Uint8List bytes) async {
    var uri = await platform.invokeMethod<String?>('saveFile', {
      'initialFilename': initialFilename,
      'mime': mime,
      'bytes': bytes
    });
    return uri;
  }

  static Future<Uint8List?> loadFile(String mime) async {
    var bytes = await platform.invokeMethod<Uint8List?>('loadFile', {
      'mime': mime
    });
    return bytes;
  }
}
