// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../util/locale_manager.dart';
import '../util/recording_manager.dart';
import '../util/time_util.dart';

class ImportRecord {
  const ImportRecord({
    required this.meta,
    required this.samples
  });

  final RecordingMeta meta;
  final List<int> samples;

  static Future<ImportRecord> fromFile(RecordingFile file) async {
    var meta = await file.loadMeta();
    var samples = await file.loadSamples();
    return ImportRecord(meta: meta, samples: samples);
  }

  RecordingFile toFile() {
    var file = RecordingFile.fromMetaAndSamples(meta, samples);
    return file;
  }

  static ImportRecord fromJson(Map<String, dynamic> json) {
    return ImportRecord(
      meta: RecordingMeta.fromJson(json['meta']),
      samples: (json['samples'] as List<dynamic>).cast<int>()
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meta': meta.toJson(),
      'samples': samples
    };
  }
}

class ImportData {
  const ImportData({
    required this.version,
    required this.createdAt,
    required this.records
  });

  static const curVersion = 1;

  final int version;
  final DateTime createdAt;
  final List<ImportRecord> records;

  static Future<ImportData> fromFiles(List<RecordingFile> files) async {
    var records = <ImportRecord>[];
    for(var file in files) {
      var record = await ImportRecord.fromFile(file);
      records.add(record);
    }
    return ImportData(
      version: curVersion,
      createdAt: DateTime.now(),
      records: records
    );
  }

  static ImportData fromJson(Map<String, dynamic> json, BuildContext context) {
    var fileVersion = json['version'] as int;
    if(fileVersion > curVersion)
      throw Exception(L(context).importDataVersionIsBigger(fileVersion: fileVersion, curVersion: curVersion));

    var records = <ImportRecord>[];
    for(var item in json['records'] as List<dynamic>) {
      try {
        var record = ImportRecord.fromJson(item);
        records.add(record);
      } catch(e) {
        //
      }
    }

    return ImportData(
      version: fileVersion,
      createdAt: TimeUtil.strToTime(json['createdAt'])!,
      records: records
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'createdAt': TimeUtil.timeToStr(createdAt),
      'records': records.map((r) => r.toJson()).toList()
    };
  }
}
