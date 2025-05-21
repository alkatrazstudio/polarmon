// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';

import 'package:flutter/material.dart';

import '../util/files_selector.dart';
import '../util/import_data.dart';
import '../util/locale_manager.dart';
import '../util/recording_manager.dart';
import '../util/storage.dart';
import '../widgets/dialogs.dart';
import '../widgets/pad.dart';

class ExportPage extends StatefulWidget {
  const ExportPage();

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  var selectedFiles = <RecordingFile>[];
  var allFiles = <RecordingFile>[];
  Future<void>? exportFuture;

  @override
  void initState() {
    super.initState();
    allFiles = RecordingManager.notifier.value.reversed.toList();
    selectedFiles = allFiles.toList();
  }

  Future<void> export() async {
    try {
      var importData = await ImportData.fromFiles(selectedFiles);
      var json = importData.toJson();
      var bytes = utf8.encode(jsonEncode(json));
      var uri = await Storage.saveFile('polarmon.json', 'application/json', bytes);
      if(uri == null)
        return;
      Navigator.pop(context);
      showPopupMsg(context, L(context).exportDone);
    } catch(e) {
      Navigator.pop(context);
      showPopupMsg(context, L(context).exportFailed(error: e.toString()));
    }
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L(context).exportTitle),
      ),
      body: Column(
        children: [
          Text(L(context).exportListInstructions).padHorizontal,
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
            future: exportFuture,
            builder: (context, snapshot) {
              var isRunning = exportFuture != null && snapshot.connectionState != ConnectionState.done;
              return ElevatedButton(
                onPressed: isRunning || selectedFiles.isEmpty ? null : () {
                  setState(() {
                    exportFuture = export();
                  });
                },
                child: isRunning ? const CircularProgressIndicator() : Text(L(context).exportActionBtn)
              );
            }
          ),
        ],
      ),
    );
  }
}
