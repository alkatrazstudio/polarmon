// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

abstract class FileUtil {
  static const maxRndInt = 1<<32;

  static Future<String> rootDir() async {
    var rootDir = await getApplicationDocumentsDirectory();
    var convDir = Directory('${rootDir.path}/data');
    await convDir.create(recursive: true);
    return convDir.path;
  }

  static Future<File> file(String filename) async {
    var root = await rootDir();
    var file = File('$root/$filename');
    await file.parent.create(recursive: true);
    return file;
  }

  static File tmpFileFor(File file) {
    var tmpFilename = '${Directory.systemTemp.path}/${file.uri.pathSegments.last}.${Random().nextInt(maxRndInt)}.tmp';
    var tmpFile = File(tmpFilename);
    return tmpFile;
  }

  static Future<void> writeBytesSafe(File file, List<int> bytes) async {
    var tmpFile = tmpFileFor(file);
    await tmpFile.writeAsBytes(bytes, flush: true);
    await tmpFile.rename(file.path);
  }

  static Future<void> writeJsonSafe(File file, dynamic object) async {
    var json = jsonEncode(object);
    var tmpFile = tmpFileFor(file);
    await tmpFile.writeAsString(json, flush: true);
    await tmpFile.rename(file.path);
  }
}
