// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../util/future_util.dart';
import '../util/locale_manager.dart';
import '../util/recording_manager.dart';
import '../util/settings.dart';
import '../widgets/dialogs.dart';
import '../widgets/graph.dart';
import '../widgets/main_menu_item.dart';
import '../widgets/pad.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({
    required this.file
  });

  final RecordingFile file;

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  late RecordingFile file;

  @override
  void initState() {
    super.initState();
    file = widget.file;
  }

  Future<String> title() async {
    var meta = await file.loadMeta();
    return meta.title;
  }

  Future<String> header() async {
    var title = await this.title();
    if(title.isEmpty)
      return file.timeString;
    return title;
  }

  Future<(RecordingMeta, List<int>)> loadMetaAndSamples() async {
    var meta = await file.loadMeta();
    var samples = await file.loadSamples();
    return (meta, samples);
  }

  Widget menu(BuildContext context) {
    return MainMenu(items: [
      MainMenuItem(L(context).recordingMenuRename, Icons.drive_file_rename_outline, () async {
        var suggestions = await RecordingManager.autocompleteTitles.load();
        var newTitle = await showSaveDialog(
          context: context,
          title: L(context).recordingRenameDialogTitle,
          suggestions: suggestions,
          initialText: await title()
        );
        if(newTitle == null)
          return;
        var newFile = await RecordingManager.rename(file, newTitle, context).showErrorToUser(context);
        setState(() {
          file = newFile;
        });
      }),
      MainMenuItem(L(context).recordingMenuDelete, Icons.delete, () async {
        var dateFormat = DateFormat.yMMMd().add_jms();
        var text = '${L(context).recordingDeleteTitle}\n\n${await title()}\n\n${L(context).recordingDeleteStart(startTime: dateFormat.format(file.startTime))}\n${L(context).recordingDeleteEnd(endTime: dateFormat.format(file.endTime))}';
        if(!await showConfirmDialog(context: context, text: text))
          return;
        await RecordingManager.delete(file).showErrorToUser(context);
        Navigator.pop(context);
      })
    ]);
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder(future: header(), builder: (context, snapshot) => Text(snapshot.data ?? '')),
        actions: [menu(context)],
      ),
      body: SafeArea(
        child: FutureBuilder(
          future: loadMetaAndSamples().showErrorToUser(context),
          builder: (context, snapshot) {
            var data = snapshot.data;
            if(data == null)
              return const Center(child: CircularProgressIndicator());
            var (meta, samples) = data;

            var minTS = file.startTime.microsecondsSinceEpoch;
            var maxTS = file.endTime.microsecondsSinceEpoch;

            var points = <FlSpot>[];
            var ts = minTS;
            for(var hr in samples) {
              if(hr != 0) {
                var point = FlSpot(ts.toDouble(), hr.toDouble());
                points.add(point);
              }
              ts += 1000000;
            }

            return Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: RecordingManager.notifier,
                  builder: (context, recs, child) {
                    var index = recs.indexOf(file);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: index <= 0 ? null : () {
                            setState(() {
                              file = recs[index - 1];
                            });
                          },
                          icon: const Icon(Icons.skip_previous)
                        ),
                        Text(
                          '${DateFormat.yMMMMd().format(file.startTime)}\n${DateFormat.jm().format(file.startTime)} - ${DateFormat.jm().format(file.endTime)}',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        IconButton(
                          onPressed: index >= (recs.length - 1) ? null : () {
                            setState(() {
                              file = recs[index + 1];
                            });
                          },
                          icon: const Icon(Icons.skip_next)
                        ),
                      ],
                    );
                  },
                ),
                Pad.verticalSpace,
                ValueListenableBuilder(
                  valueListenable: Settings.notifier,
                  builder: (context, settings, child) {
                    int maxHr;
                    int minHr;
                    if(settings.hrCustomEnable) {
                      maxHr = settings.hrCustomMax;
                      minHr = settings.hrCustomMin;
                    } else {
                      maxHr = samples.where((hr) => hr > 0).reduce((value, element) => max(value, element));
                      minHr = samples.where((hr) => hr > 0).reduce((value, element) => min(value, element));
                    }

                    return Graph(
                      key: ValueKey(file),
                      maxVal: maxHr,
                      minVal: minHr,
                      minTS: minTS,
                      maxTS: maxTS,
                      points: points,
                      offsetFromEnd: false,
                      clipX: false,
                      marks: meta.marks,
                      customRangeIsUsed: settings.hrCustomEnable
                    );
                  },
                )
              ],
            );
          },
        )
      )
    );
  }
}
