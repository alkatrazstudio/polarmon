// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../util/recording_manager.dart';
import '../util/settings.dart';
import '../widgets/dialogs.dart';
import '../widgets/graph.dart';
import '../widgets/main_menu_item.dart';
import '../widgets/pad.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({
    required this.rec
  });

  final SavedRecording rec;

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  late SavedRecording rec;

  String get title => rec.title.isEmpty ? rec.timeString : rec.title;

  @override
  void initState() {
    super.initState();
    rec = widget.rec;
  }

  Widget menu(BuildContext context) {
    return MainMenu(items: [
      MainMenuItem('Rename', Icons.drive_file_rename_outline, () async {
        var newTitle = await showSaveDialog(
          context: context,
          title: 'Name for this recording',
          suggestions: RecordingManager.titlesForAutocomplete(),
          initialText: rec.title
        );
        if(newTitle == null)
          return;
        await RecordingManager.rename(rec, newTitle);
        setState(() {});
      }),
      MainMenuItem('Delete', Icons.delete, () async {
        var fmt = DateFormat.yMMMd().add_Hms();
        var text = 'Delete this recording:\n\n$title\n\nStart: ${fmt.format(rec.startTime)}\nEnd: ${fmt.format(rec.endTime)}';
        if(!await showConfirmDialog(context: context, text: text))
          return;
        await RecordingManager.delete(rec);
        Navigator.pop(context);
      })
    ]);
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [menu(context)],
      ),
      body: SafeArea(
        child: FutureBuilder<List<int>>(
          future: rec.getSamples(),
          builder: (context, snapshot) {
            var samples = snapshot.data;
            if(samples == null)
              return const CircularProgressIndicator();

            var minTS = rec.startTime.microsecondsSinceEpoch;
            var maxTS = rec.endTime.microsecondsSinceEpoch;

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
                    var index = recs.indexOf(rec);
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: index <= 0 ? null : () {
                            setState(() {
                              rec = recs[index - 1];
                            });
                          },
                          icon: const Icon(Icons.skip_previous)
                        ),
                        Text(
                          rec.timeString,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        IconButton(
                          onPressed: index >= (recs.length - 1) ? null : () {
                            setState(() {
                              rec = recs[index + 1];
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
                      key: ValueKey(rec),
                      maxVal: maxHr,
                      minVal: minHr,
                      minTS: minTS,
                      maxTS: maxTS,
                      points: points,
                      offsetFromEnd: false,
                      clipX: false,
                      marks: rec.marks,
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
