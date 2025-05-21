// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../pages/export_page.dart';
import '../pages/import_page.dart';
import '../pages/recording_page.dart';
import '../util/locale_manager.dart';
import '../util/recording_manager.dart';
import '../widgets/dialogs.dart';
import '../widgets/search_field.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer();

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  var search = '';

  @override
  Widget build(context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            SearchField(
              onChanged: (s) {
                setState(() {
                  search = s;
                });
              },
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: RecordingManager.notifier,
                builder: (context, files, child) {
                  files = RecordingManager.filter(files, search).reversed.toList();
                  return ListView.separated(
                    itemCount: files.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      var item = files[index];
                      return ListTile(
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
                      );
                    },
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
                  child: Text(L(context).appDrawerExport)
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      var importData = await ImportPage.loadData(context);
                      if(importData == null)
                        return;
                      Navigator.pop(context);
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute(builder: (context) => ImportPage(importData: importData))
                      );
                    } catch(e) {
                      Navigator.pop(context);
                      showPopupMsg(context, L(context).appDrawerImportFailed(error: e.toString()));
                    }
                  },
                  child: Text(L(context).appDrawerImport)
                )
              ]
            )
          ],
        ),
      )
    );
  }
}
