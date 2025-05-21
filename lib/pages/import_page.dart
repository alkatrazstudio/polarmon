// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../util/files_selector.dart';
import '../util/import_data.dart';
import '../util/locale_manager.dart';
import '../util/recording_manager.dart';
import '../util/storage.dart';
import '../widgets/dialogs.dart';
import '../widgets/pad.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({
    required this.importData
  });

  final ImportData importData;

  @override
  State<ImportPage> createState() => _ImportPageState();

  static Future<ImportData?> loadData(BuildContext context) async {
    var bytes = await Storage.loadFile('application/json');
    if(bytes == null)
      return null;
    var json = utf8.decode(bytes);
    var jsonObj = jsonDecode(json) as Map<String, dynamic>;
    var importData = ImportData.fromJson(jsonObj, context);
    return importData;
  }
}

class _ImportPageState extends State<ImportPage> {
  var selectedFiles = <RecordingFile>[];
  var allFiles = <RecordingFile>[];
  Future<void>? importFuture;

  @override
  void initState() {
    super.initState();
    allFiles = widget.importData.records.sortedBy((r) => r.meta.startTime).reversed.map((r) => r.toFile()).toList();
    selectedFiles = allFiles.toList();
  }

  Future<void> import() async {
    try {
      var failedFiles = <RecordingFile>[];
      for(var file in selectedFiles) {
        try {
          var existingFile = RecordingManager.notifier.value.firstWhereOrNull((r) => r.id == file.id);
          if(existingFile != null)
            await RecordingManager.delete(existingFile);
          await file.resave();
        } catch(e) {
          failedFiles.add(file);
        }
      }
      Navigator.pop(context);
      if(failedFiles.isEmpty) {
        showPopupMsg(context, L(context).importDone);
      } else {
        var failedNames = failedFiles.map((c) => c.fileTitle.isEmpty ? c.timeString : c.fileTitle).join(', ');
        showPopupMsg(context, L(context).importPartiallyDone(names: failedNames));
      }
    } catch(e) {
      Navigator.pop(context);
      showPopupMsg(context, L(context).importFailed(error: e.toString()));
    }
    await RecordingManager.loadList();
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L(context).importTitle)
      ),
      body: Column(
        children: [
          Text(L(context).importFileDate(createdAt: '${DateFormat.yMMMd().format(widget.importData.createdAt)}, ${DateFormat.jm().format(widget.importData.createdAt)}')),
          Text(L(context).importListInstructions).padHorizontal,
          Expanded(
            child: FilesSelector(
              allFiles: allFiles,
              selectedFiles: selectedFiles,
              onChanged: (newSelectedFiles) {
                setState(() {
                  selectedFiles = newSelectedFiles;
                });
              },
            ),
          ),
          FutureBuilder(
            future: importFuture,
            builder: (context, snapshot) {
              var isRunning = importFuture != null && snapshot.connectionState != ConnectionState.done;
              return ElevatedButton(
                onPressed: isRunning || selectedFiles.isEmpty ? null : () {
                  setState(() {
                    importFuture = import();
                  });
                },
                child: isRunning ? const CircularProgressIndicator() : Text(L(context).importActionBtn)
              );
            }
          ),
        ],
      ),
    );
  }
}
