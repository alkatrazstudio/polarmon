// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../pages/recording_page.dart';
import '../util/device.dart';
import '../util/mark_manager.dart';
import '../util/recording_manager.dart';
import '../util/time_util.dart';
import '../widgets/dialogs.dart';
import '../widgets/pad.dart';

class RecordingPanel extends StatefulWidget {
  const RecordingPanel({
    required this.device
  });

  final Device device;

  @override
  State<RecordingPanel> createState() => _RecordingPanelState();
}

String durationStr(DateTime? startedAt) {
  if(startedAt == null)
    return 'N/A minutes';
  var duration = DateTime.now().difference(startedAt);
  var str = TimeUtil.durationToHumanStr(duration);
  return str;
}

class _RecordingPanelState extends State<RecordingPanel> {
  Future<void>? recFuture;

  Future<void> saveRecording() async {
    var rec = await widget.device.getRecording();
    if(rec == null)
      return;
    var title = await showSaveDialog(
      context: context,
      title: 'Name for this recording',
      suggestions: RecordingManager.titlesForAutocomplete()
    );
    var marks = (MarkManager.notifier.value ?? []).where((mark) => mark.startAt.microsecondsSinceEpoch >= rec.startedAt.microsecondsSinceEpoch).toList();
    var savedRec = await RecordingManager.add(rec, title ?? '', marks);
    await widget.device.deleteRecording();
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => RecordingPage(rec: savedRec))
    );
  }

  Future<void> stopRecording() async {
    await widget.device.stopRecording();
    await saveRecording();
  }

  Future<void> createMark(bool expectingEnd) async {
    var mark = Mark(expectingEnd: expectingEnd);
    var title = await showSaveDialog(
      context: context,
      title: expectingEnd ? 'Name this interval' : 'Name this mark',
      suggestions: MarkManager.titlesForAutocomplete()
    );
    if(title == null)
      return;
    if(title.isEmpty)
      title = 'N/A';
    mark.title = title;
    await MarkManager.save(mark);
  }

  @override
  Widget build(context) {
    return Card(
      child: Row(
        children: [
          ValueListenableBuilder(
            valueListenable: widget.device.recordingStatus,
            builder: (context, status, child) {
              if(status == null)
                return const SizedBox();
              var color = status.isOngoing ? Colors.red : Theme.of(context).disabledColor;
              return Row(
                children: [
                  ElevatedButton(
                    onPressed: recFuture != null ? null : () {
                      var newRecFuture = status.isOngoing
                        ? stopRecording()
                        : (status.startedAt == null ? widget.device.startRecording() : saveRecording());
                      newRecFuture.whenComplete(() => setState(() {
                        recFuture = null;
                      }));
                      setState(() {
                        recFuture = newRecFuture;
                      });
                    },
                    child: recFuture == null
                      ? Text(status.isOngoing ? 'Stop' : (status.startedAt == null ? 'Start' : 'Save'))
                      : const CircularProgressIndicator()
                  ),
                  Icon(
                    Icons.fiber_manual_record_rounded,
                    color: color,
                    size: 30,
                  ),
                  Text(
                    'REC',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color
                    )
                  ),
                  Pad.horizontalSpace,
                  if(status.isOngoing)
                    StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        return Text(
                          durationStr(status.startedAt),
                          style: const TextStyle(
                            fontFamily: 'monospace'
                          )
                        );
                      }
                    ),
                  if(!status.isOngoing && status.startedAt != null)
                    Text(
                      DateFormat.yMMMd().addPattern('\n').add_Hms().format(status.startedAt!),
                      textAlign: TextAlign.center,
                    ),
                ],
              );
            }
          ),
          const Spacer(),
          ValueListenableBuilder(
            valueListenable: MarkManager.notifier,
            builder: (context, marks, child) {
              if(marks == null)
                return const SizedBox();
              var lastMark = marks.lastOrNull;
              var expectingEnd = lastMark != null ? (lastMark.expectingEnd && lastMark.endAt == null) : false;
              return Row(
                children: [
                  IconButton(
                    onPressed: expectingEnd ? null : () async {
                      await createMark(false);
                    },
                    icon: const Icon(Icons.bookmark_add),
                  ),
                  if(expectingEnd)
                    Transform.rotate(
                      angle: pi/2,
                      child: IconButton(
                        onPressed: () async {
                          lastMark.endAt = DateTime.now();
                          await MarkManager.save(lastMark);
                        },
                        icon: const Icon(Icons.vertical_align_top),
                      )
                    )
                  else
                    IconButton(
                      onPressed: () async {
                        await createMark(true);
                      },
                      icon: const Icon(Icons.start),
                    )
                ],
              );
            },
          )
        ]
      )
    );
  }
}
