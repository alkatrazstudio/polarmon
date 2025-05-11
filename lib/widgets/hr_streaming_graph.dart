// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

import '../util/device.dart';
import '../util/mark_manager.dart';
import '../util/settings.dart';
import '../widgets/graph.dart';

class HrStreamingGraph extends StatefulWidget {
  const HrStreamingGraph({
    required this.hrStream,
    required this.recordingStatus
  });

  final Stream<int>? hrStream;
  final ValueNotifier<DeviceRecordingStatus?> recordingStatus;

  @override
  State<HrStreamingGraph> createState() => _HrStreamingGraphState();
}

class _HrStreamingGraphState extends State<HrStreamingGraph> {
  var minHr = 1000;
  var maxHr = 0;
  var maxTS = 0;
  var defaultMins = 5;

  var points = <FlSpot>[];

  @override
  Widget build(context) {
    return StreamBuilder(
      stream: widget.hrStream,
      builder: (context, snapshot) {
        var hr = snapshot.data;
        var ts = DateTime.now().microsecondsSinceEpoch;
        maxTS = ts;
        var minTS = maxTS - max(points.length, defaultMins * 60) * 1000000;
        if(hr != null && hr != 0) {
          var point = FlSpot(ts.toDouble(), hr.toDouble());
          points.add(point);
          if(hr > maxHr)
            maxHr = hr;
          if(hr < minHr)
            minHr = hr;
        }
        return ValueListenableBuilder(
          valueListenable: Settings.notifier,
          builder: (context, settings, child) {
            var minVal = settings.hrCustomEnable ? settings.hrCustomMin : minHr;
            var maxVal = settings.hrCustomEnable ? settings.hrCustomMax : maxHr;
            var recordingStartedAt = widget.recordingStatus.value?.startedAt;
            if(points.length < 2)
              return Graph(
                key: const ValueKey('hr-graph-dummy'),
                points: const [],
                minVal: minVal,
                maxVal: maxVal,
                minTS: minTS,
                maxTS: maxTS,
                offsetFromEnd: true,
                clipX: false,
                recordingStartedAt: recordingStartedAt,
                customRangeIsUsed: settings.hrCustomEnable
              );
            return Graph(
              key: const ValueKey('hr-graph'),
              points: points,
              minVal: minVal,
              maxVal: maxVal,
              minTS: minTS,
              maxTS: maxTS,
              offsetFromEnd: true,
              clipX: false,
              marks: MarkManager.notifier.value ?? [],
              recordingStartedAt: recordingStartedAt,
              customRangeIsUsed: settings.hrCustomEnable
            );
          }
        );
      },
    );
  }
}
