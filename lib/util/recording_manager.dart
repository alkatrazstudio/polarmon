// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../util/device.dart';
import '../util/file_util.dart';
import '../util/mark_manager.dart';
import '../util/time_util.dart';

class RecordingMeta {
  RecordingMeta({
    required this.title,
    required DateTime startTime,
    required DateTime endTime,
    required this.marks
  }):
    startTime = startTime.toLocal(),
    endTime = endTime.toLocal();

  String title;
  final DateTime startTime;
  final DateTime endTime;
  final List<Mark> marks;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': TimeUtil.timeToStr(startTime.toUtc()),
      'endTime': TimeUtil.timeToStr(endTime.toUtc()),
      'marks': MarkManager.listToJson(marks)
    };
  }

  static RecordingMeta fromJson(Map<String, dynamic> json) {
    return RecordingMeta(
      title: json['title'] as String,
      startTime: TimeUtil.strToTime(json['startTime'] as String)!,
      endTime: TimeUtil.strToTime(json['endTime'] as String)!,
      marks: MarkManager.listFromJson((json['marks'] as List<dynamic>?) ?? [])
    );
  }
}

class RecordingFile {
  RecordingFile({
    required this.startTime,
    required this.endTime,
    required this.fileTitle,
    RecordingMeta? meta,
    List<int>? samples,
  }):
    _meta = meta,
    _samples = samples;

  final DateTime startTime;
  final DateTime endTime;
  String fileTitle;
  RecordingMeta? _meta;
  List<int>? _samples;
  Future<RecordingMeta>? _metaFuture;
  Future<List<int>>? _samplesFuture;

  static final RegExp rxFilename = RegExp(r'^(\d{14})_(\d{14})(?:_(.*))?.json$');
  // 128 bytes (not chars) is the maximum filename length on Android.
  // There is also 30 chars prefix (20240612114512_20240612123720_) and 5 chars suffix (.json).
  // 128 - 30 - 5 = 93, but reserve some bytes just in case
  static const maxCleanTitleByteLen = 64;
  static final forbiddenNameCharsRx = RegExp(r'''[^\p{Letter}\p{Number}'"\$\-_,\(\)\[\]\{\}<>@!\?\|:_ ]''', unicode: true);
  static const baseDirName = 'recordings';

  String get id => '${TimeUtil.timeToStr(startTime)}_${TimeUtil.timeToStr(endTime)}';

  String get metaFileBasename {
    var fileTitle = this.fileTitle;
    var filename = '$id${fileTitle.isEmpty ? '' : '_'}$fileTitle.json';
    return filename;
  }

  String get timeString {
    var diff = DateTime.now().difference(startTime);
    var startFormat = diff.inDays > 30 * 10 ? DateFormat.yMMMd() : DateFormat().add_MMMd();
    var startDateStr = startFormat.format(startTime);
    var startTimeStr = DateFormat().add_Hm().format(startTime);
    var endTimeStr = DateFormat().add_Hm().format(endTime);
    return '$startDateStr: $startTimeStr - $endTimeStr';
  }

  static Future<String> baseDir() async {
    var rootDir = await FileUtil.rootDir();
    var baseDir = '$rootDir/$baseDirName';
    return baseDir;
  }

  Future<File> samplesFile() async {
    var filename = '$baseDirName/samples/$id.samples';
    var file = FileUtil.file(filename);
    return file;
  }

  Future<void> saveSamples(List<int> samples) async {
    var file = await samplesFile();
    await file.writeAsBytes(samples, flush: true);
    _samples = samples;
    _samplesFuture = null;
  }

  Future<List<int>> _loadSamples() async {
    var file = await samplesFile();
    var samples = await file.readAsBytes();
    return samples;
  }

  Future<List<int>> loadSamples() async {
    if(_samples != null)
      return _samples!;
    _samplesFuture ??= _loadSamples();
    var samplesFromFile = await _samplesFuture!;
    return samplesFromFile;
  }

  Future<void> deleteSamples() async {
    var file = await samplesFile();
    await file.delete();
  }

  Future<File> metaFile() async {
    var file = FileUtil.file('$baseDirName/$metaFileBasename');
    return file;
  }

  Future<void> saveMeta(RecordingMeta meta) async {
    var jsonObj = meta.toJson();
    var json = jsonEncode(jsonObj);
    var file = await metaFile();
    await file.writeAsString(json);
    _meta = meta;
    _metaFuture = null;
  }

  Future<RecordingMeta> _loadMeta() async {
    var file = await metaFile();
    var json = await file.readAsString();
    var jsonItem = jsonDecode(json);
    var rec = RecordingMeta.fromJson(jsonItem);
    return rec;
  }

  Future<RecordingMeta> loadMeta() async {
    if(_meta != null)
      return _meta!;
    _metaFuture ??= _loadMeta();
    var metaFromFile = await _metaFuture!;
    return metaFromFile;
  }

  Future<void> deleteMeta() async {
    var file = await metaFile();
    await file.delete();
  }

  static RecordingFile? fromFile(File file) {
    var m = rxFilename.firstMatch(p.basename(file.path));
    if(m == null)
      return null;
    var startTime = TimeUtil.strToTime(m.group(1)!)!.toLocal();
    var endTime = TimeUtil.strToTime(m.group(2)!)!.toLocal();
    var fileTitle = m.group(3) ?? '';
    return RecordingFile(
      startTime: startTime,
      endTime: endTime,
      fileTitle: fileTitle
    );
  }

  static Future<RecordingFile> fromMetaAndSamples(RecordingMeta meta, List<int>? samples) async {
    var fileTitle = meta.title.replaceAll(forbiddenNameCharsRx, '').trim();
    while(utf8.encode(fileTitle).lengthInBytes > maxCleanTitleByteLen)
      fileTitle = fileTitle.substring(0, fileTitle.length - 1);
    fileTitle = fileTitle.trim();
    return RecordingFile(
      startTime: meta.startTime,
      endTime: meta.endTime,
      fileTitle: fileTitle,
      meta: meta,
      samples: samples
    );
  }

  RecordingFile clone() {
    var file = RecordingFile(
      startTime: startTime,
      endTime: endTime,
      fileTitle: fileTitle,
    );
    file._meta = _meta;
    file._samples = _samples;
    return file;
  }
}

abstract class RecordingManager {
  static final notifier = ValueNotifier<List<RecordingFile>>([]);

  static Future<File> listFile() async {
    var file = FileUtil.file('recordings/recordings.json');
    return file;
  }

  static Future<void> migrateSamples() async {
    var rootDir = await FileUtil.rootDir();
    var fromDir = Directory('$rootDir/recording');
    if(!await fromDir.exists())
      return;
    var toDir = Directory('$rootDir/recordings/samples');
    await toDir.create(recursive: true);
    var fromDirHasExtraFiles = false;
    await for (var entry in fromDir.list()) {
      if(entry is File && entry.path.endsWith('.samples')) {
        var newPath = '${toDir.path}/${p.basename(entry.path)}';
        await entry.rename(newPath);
      } else {
        fromDirHasExtraFiles = true;
      }
    }
    if(!fromDirHasExtraFiles) {
      try {
        await fromDir.delete();
      } catch(e) {
        //
      }
    }
  }

  static Future<void> migrateMeta() async {
    var rootDir = await FileUtil.rootDir();
    var allFile = File('$rootDir/recordings/recordings.json');
    if(!await allFile.exists())
      return;
    var allJson = await allFile.readAsString();
    var jsonItems = jsonDecode(allJson) as List<dynamic>;
    for(var jsonItem in jsonItems) {
      try {
        var meta = RecordingMeta.fromJson(jsonItem as Map<String, dynamic>);
        var file = await RecordingFile.fromMetaAndSamples(meta, null);
        await file.saveMeta(meta);
      } catch(e) {
        //
      }
    }
    try {
      await allFile.delete();
    } catch(e) {
      //
    }
  }

  static Future<void> loadList() async {
    await migrateSamples();
    await migrateMeta();

    var dir = Directory(await RecordingFile.baseDir());
    var files = <RecordingFile>[];
    await for(var entry in dir.list()) {
      if(entry is! File)
        continue;
      var recFile = RecordingFile.fromFile(entry);
      if(recFile != null)
        files.add(recFile);
    }
    files.sortBy((f) => f.startTime);
    notifier.value = files;
  }

  static Future<RecordingFile> add(DeviceRecording rec, String title, List<Mark> marks) async {
    var endTime = rec.startedAt.add(Duration(seconds: rec.samples.length));
    var meta = RecordingMeta(
      title: title,
      startTime: rec.startedAt,
      endTime: endTime,
      marks: marks
    );
    var file = await RecordingFile.fromMetaAndSamples(meta, rec.samples);
    await file.saveSamples(rec.samples);
    await file.saveMeta(meta);
    notifier.value = [...notifier.value, file];
    return file;
  }

  static Future<void> delete(RecordingFile fileToDelete) async {
    var files = [...notifier.value];
    var recIndex = files.indexWhere((f) => f.id == fileToDelete.id);
    if(recIndex >= 0) {
      var file = files.removeAt(recIndex);
      await file.deleteMeta();
      await file.deleteSamples();
    }
    notifier.value = files;
  }

  static Future<RecordingFile> rename(RecordingFile recToRename, String newTitle) async {
    var files = [...notifier.value];
    var fileIndex = files.indexWhere((rec) => rec.id == recToRename.id);
    if(fileIndex < 0)
      throw Exception('No file found');
    var oldFile = files[fileIndex];
    var meta = await oldFile.loadMeta();
    meta.title = newTitle;
    var newFile = await RecordingFile.fromMetaAndSamples(meta, null);
    await newFile.saveMeta(meta);
    await oldFile.deleteMeta();
    files[fileIndex] = newFile;
    notifier.value = files;
    return newFile;
  }

  static List<String> titlesForAutocomplete() {
    var suggestions = notifier
      .value
      .sortedBy((rec) => rec.startTime)
      .reversed
      .map((rec) => rec.fileTitle) // TODO: get real title
      .where((title) => title.isNotEmpty)
      .toSet()
      .toList();
    return suggestions;
  }
}
