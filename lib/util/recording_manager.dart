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

class SavedRecording {
  SavedRecording({
    required this.id,
    required this.title,
    required DateTime startTime,
    required DateTime endTime,
    required this.marks
  }):
    startTime = startTime.toLocal(),
    endTime = endTime.toLocal();

  final String id;
  String title;
  final DateTime startTime;
  final DateTime endTime;
  final List<Mark> marks;

  Future<File> samplesFile() async {
    var cleanId = id.replaceAll('.', '').replaceAll('/', '').trim();
    var filename = 'recordings/$cleanId.samples';
    var file = FileUtil.file(filename);
    return file;
  }

  Future<void> saveSamples(List<int> samples) async {
    var file = await samplesFile();
    await file.writeAsBytes(samples, flush: true);
  }

  Future<List<int>> getSamples() async {
    var file = await samplesFile();
    var samples = await file.readAsBytes();
    return samples;
  }

  Future<void> deleteSamples() async {
    var file = await samplesFile();
    await file.delete();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'startTime': TimeUtil.timeToStr(startTime.toUtc()),
      'endTime': TimeUtil.timeToStr(endTime.toUtc()),
      'marks': MarkManager.listToJson(marks)
    };
  }

  static SavedRecording fromJson(Map<String, dynamic> json) {
    return SavedRecording(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: TimeUtil.strToTime(json['startTime'] as String)!,
      endTime: TimeUtil.strToTime(json['endTime'] as String)!,
      marks: MarkManager.listFromJson((json['marks'] as List<dynamic>?) ?? [])
    );
  }

  String get timeString {
    var diff = DateTime.now().difference(startTime);
    var startFormat = diff.inDays > 30 * 10 ? DateFormat.yMMMd() : DateFormat().add_MMMd();
    var startDateStr = startFormat.format(startTime);
    var startTimeStr = DateFormat().add_Hm().format(startTime);
    var endTimeStr = DateFormat().add_Hm().format(endTime);
    return '$startDateStr: $startTimeStr - $endTimeStr';
  }
}

abstract class RecordingManager {
  static final notifier = ValueNotifier<List<SavedRecording>>([]);

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

  static Future<List<SavedRecording>> loadList() async {
    await migrateSamples();
    var recs = <SavedRecording>[];
    try {
      var file = await listFile();
      var json = await file.readAsString();
      var jsonArr = jsonDecode(json) as List<dynamic>;
      for(var jsonItem in jsonArr) {
        try {
          var rec = SavedRecording.fromJson(jsonItem as Map<String, dynamic>);
          recs.add(rec);
        } catch(e) {
          //
        }
      }
    } catch(e) {
      //
    }
    notifier.value = recs;
    return recs;
  }

  static Future<void> saveList(List<SavedRecording> recs) async {
    var items = <Map<String,dynamic>>[];
    for(var rec in recs) {
      var item = rec.toJson();
      items.add(item);
    }
    var json = jsonEncode(items);
    var file = await listFile();
    await file.writeAsString(json, flush: true);
    notifier.value = recs;
  }

  static Future<SavedRecording> add(DeviceRecording rec, String title, List<Mark> marks) async {
    var endTime = rec.startedAt.add(Duration(seconds: rec.samples.length));
    var recId = '${TimeUtil.timeToStr(rec.startedAt)}_${TimeUtil.timeToStr(endTime)}';
    var savedRec = SavedRecording(
      id: recId,
      title: title,
      startTime: rec.startedAt,
      endTime: endTime,
      marks: marks
    );
    await savedRec.saveSamples(rec.samples);
    var recs = await loadList();
    recs.add(savedRec);
    await saveList(recs);
    return savedRec;
  }

  static Future<void> delete(SavedRecording recToDelete) async {
    var recs = await loadList();
    var recIndex = recs.indexWhere((rec) => rec.id == recToDelete.id);
    if(recIndex >= 0)
      recs.removeAt(recIndex);
    await saveList(recs);
    await recToDelete.deleteSamples();
  }

  static Future<void> rename(SavedRecording recToRename, String newTitle) async {
    var recs = await loadList();
    var rec = recs.firstWhereOrNull((rec) => rec.id == recToRename.id);
    if(rec == null)
      return;
    rec.title = newTitle;
    await saveList(recs);
    recToRename.title = newTitle;
  }

  static List<String> titlesForAutocomplete() {
    var suggestions = notifier
      .value
      .sortedBy((rec) => rec.startTime)
      .reversed
      .map((rec) => rec.title)
      .where((title) => title.isNotEmpty)
      .toSet()
      .toList();
    return suggestions;
  }
}
