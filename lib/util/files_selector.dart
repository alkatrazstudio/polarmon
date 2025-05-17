// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../util/recording_manager.dart';
import '../widgets/pad.dart';
import '../widgets/search_field.dart';

class FilesSelector extends StatefulWidget {
  const FilesSelector({
    required this.allFiles,
    required this.selectedFiles,
    required this.onChanged
  });

  final List<RecordingFile> allFiles;
  final List<RecordingFile> selectedFiles;
  final void Function(List<RecordingFile> newSelectedFiles) onChanged;

  @override
  State<FilesSelector> createState() => _FilesSelectorState();
}

class _FilesSelectorState extends State<FilesSelector> {
  var search = '';

  @override
  Widget build(context) {
    var curFiles = RecordingManager.notifier.value;
    var allFiles = RecordingManager.filter(widget.allFiles, search);
    return Column(
      children: [
        SearchField(
          onChanged: (s) {
            setState(() {
              search = s;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton(
              onPressed: () {
                widget.onChanged(allFiles);
              },
              child: const Text('select all')
            ),
            ElevatedButton(
              onPressed: () {
                widget.onChanged([]);
              },
              child: const Text('select none')
            ),
          ],
        ).padHorizontal,
        Expanded(
          child: ListView.builder(
            itemCount: allFiles.length,
            itemBuilder: (context, index) {
              var file = allFiles[index];
              var isNew = curFiles.indexWhere((c) => c.id == file.id) == -1;
              var isChecked = widget.selectedFiles.contains(file);
              return ListTile(
                title: Text(file.fileTitle),
                subtitle: Text(
                  file.timeString,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).disabledColor
                  )
                ),
                leading: Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    var newSelectedFileIds = widget.selectedFiles.toList();
                    if(value ?? false)
                      newSelectedFileIds.add(file);
                    else
                      newSelectedFileIds.remove(file);
                    widget.onChanged(newSelectedFileIds);
                  },
                ),
                trailing: isNew ? Icon(Icons.new_releases) : null,
                onTap: () {
                  var newSelectedFileIds = widget.selectedFiles.toList();
                  if(isChecked)
                    newSelectedFileIds.remove(file);
                  else
                    newSelectedFileIds.add(file);
                  widget.onChanged(newSelectedFileIds);
                },
              );
            }
          ),
        )
      ],
    );
  }
}
