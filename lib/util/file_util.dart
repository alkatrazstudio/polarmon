// SPDX-License-Identifier: MPL-2.0

import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class FileUtil {
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
} 
