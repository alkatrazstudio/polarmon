// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';

import '../util/file_util.dart';

class Mark {
  Mark({
    this.title = '',
    DateTime ?startAt,
    this.endAt,
    this.expectingEnd = false
  }):
    startAt = startAt ?? DateTime.now();

  String title;
  final DateTime startAt;
  DateTime? endAt;
  final bool expectingEnd;

  Map<String, dynamic> toJson() {
    var json = <String, dynamic>{
      'startAt': startAt.microsecondsSinceEpoch
    };
    if(title.isNotEmpty)
      json['title'] = title;
    if(expectingEnd && endAt == null)
      json['expectingEnd'] = expectingEnd;
    if(endAt != null)
      json['endAt'] = endAt!.microsecondsSinceEpoch;
    return json;
  }

  static Mark fromJson(Map<String, dynamic> json) {
    var endAtTS = json['endAt'] as int?;
    var mark = Mark(
      title: (json['title'] as String?) ?? '',
      startAt: DateTime.fromMicrosecondsSinceEpoch(json['startAt'] as int),
      endAt: endAtTS == null ? null : DateTime.fromMicrosecondsSinceEpoch(endAtTS),
      expectingEnd: (json['expectingEnd'] as bool?) ?? false,
    );
    return mark;
  }
}

abstract class MarkManager {
  static final notifier = ValueNotifier<List<Mark>?>(null);

  static Future<File> listFile() async {
    var file = FileUtil.file('marks.json');
    return file;
  }

  static List<Mark> listFromJson(List<dynamic> jsonArr) {
    var marks = <Mark>[];
    try {
      for(var jsonItem in jsonArr) {
        try {
          var rec = Mark.fromJson(jsonItem as Map<String, dynamic>);
          marks.add(rec);
        } catch(e) {
          //
        }
      }
    } catch(e) {
      //
    }
    return marks;
  }

  static Future<List<Mark>> loadList() async {
    List<Mark> marks;
    try {
      var file = await listFile();
      var json = await file.readAsString();
      var jsonArr = jsonDecode(json) as List<dynamic>;
      marks = listFromJson(jsonArr);
    } catch(e) {
      marks = [];
    }
    notifier.value = marks;
    return marks;
  }

  static List<Map<String,dynamic>> listToJson(List<Mark> marks) {
    var items = <Map<String,dynamic>>[];
    for(var mark in marks) {
      var item = mark.toJson();
      items.add(item);
    }
    return items;
  }

  static Future<void> saveList(List<Mark> marks) async {
    var items = listToJson(marks);
    var file = await listFile();
    await FileUtil.writeJsonSafe(file, items);
    notifier.value = marks;
  }

  static Future<void> save(Mark mark) async {
    var marks = notifier.value?.toList();
    if(marks == null)
      throw Exception('MarkManager is no ready yet.');
    var existingRecIndex = marks.indexWhere((m) => m.startAt == mark.startAt);
    if(existingRecIndex == -1)
      marks.add(mark);
    else
      marks[existingRecIndex] = mark;
    await saveList(marks);
  }

  static List<String> titlesForAutocomplete() {
    var suggestions = notifier
      .value
      ?.sortedBy((mark) => mark.startAt)
      .reversed
      .map((rec) => rec.title)
      .where((title) => title.isNotEmpty)
      .toSet()
      .toList()
      ?? [];
    return suggestions;
  }
}
