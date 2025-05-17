// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../pages/export_page.dart';
import '../pages/import_page.dart';
import '../pages/recording_page.dart';
import '../util/recording_manager.dart';
import '../widgets/dialogs.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer();

  @override
  Widget build(context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: RecordingManager.notifier,
                builder: (context, items, child) {
                  return ListView(
                    children: items.reversed.map((item) => ListTile(
                      title: Text(item.timeString),
                      subtitle: item.fileTitle.isEmpty ? null : Text(
                        item.fileTitle,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic
                        )
                      ),
                      onTap: () {
                        Navigator.push<void>(
                          context,
                          MaterialPageRoute(builder: (context) => RecordingPage(file: item))
                        );
                      },
                    )).toList(),
                  );
                },
              )
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (context) => const ExportPage())
                    );
                  },
                  child: const Text('Export')
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      var importData = await ImportPage.loadData();
                      if(importData == null)
                        return;
                      Navigator.pop(context);
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (context) => ImportPage(importData: importData))
                      );
                    } catch(e) {
                      Navigator.pop(context);
                      showPopupMsg(context, 'Import failed: $e');
                    }
                  },
                  child: const Text('Import')
                )
              ]
            )
          ],
        ),
      )
    );
  }
}
