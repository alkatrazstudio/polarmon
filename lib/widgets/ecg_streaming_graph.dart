// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

import '../util/ecg_process.dart';
import '../widgets/dialogs.dart';
import '../util/dev_build.dart';
import '../util/locale_manager.dart';
import '../util/memory_file.dart';
import '../util/settings.dart';
import '../util/storage.dart';
import '../util/time_util.dart';
import '../widgets/graph.dart';

class EcgStreamingGraph extends StatefulWidget {
  const EcgStreamingGraph({
    required this.stream
  });

  final Stream<HeartbeatWithIrregularity> stream;

  @override
  State<EcgStreamingGraph> createState() => _EcgStreamingGraphState();
}

class _EcgStreamingGraphState extends State<EcgStreamingGraph> {
  final points = <FlSpot>[];
  final ranges = <VerticalRangeAnnotation>[];
  final lines = <VerticalLine>[];

  var dummyX = DateTime.now().microsecondsSinceEpoch;

  String irrLabel(HeartbeatWithIrregularity beat) {
    var subLabels = beat.irregularityTypes.map((irr) {
      switch(irr) {
        case IrregularityType.longFullDuration:
          return 'L';
        case IrregularityType.highRAmplitude:
          return 'R▲';
        case IrregularityType.highSAmplitude:
         return 'S▲';
        case IrregularityType.lowRAmplitude:
          return 'R▼';
        case IrregularityType.lowSAmplitude:
          return 'S▼';
        case IrregularityType.longSToZeroDuration:
          return 'S0L';
        case IrregularityType.rNotch:
          return 'RR';
      }
    });
    var label = subLabels.join('\n');
    return label;
  }

  @override
  Widget build(context) {
    return StreamBuilder(
      stream: widget.stream,
      builder: (context, snapshot) {
        var beat = snapshot.data;
        if(beat != null) {
          points.addAll(
            beat.beat.samples.map((sample) => FlSpot(
              sample.tsMicroSecs.toDouble(),
              sample.voltage.toDouble()
            ))
          );
          if(beat.beat.isValid && beat.isIrregular) {
            ranges.add(
              VerticalRangeAnnotation(
                x1: beat.beat.microSecsStart.toDouble(),
                x2: beat.beat.microSecsEnd.toDouble(),
                color: Colors.red.withAlpha(64)
              )
            );
            lines.add(
              VerticalLine(
                x: beat.beat.microSecsStart.toDouble(),
                color: Colors.red,
                strokeWidth: 1,
                label: VerticalLineLabel(
                  alignment: Alignment.bottomRight,
                  show: true,
                  style: const TextStyle(
                    color: Colors.red,
                    backgroundColor: Colors.black,
                    fontSize: 16,
                    height: 1,
                  ),
                  labelResolver: (line) => irrLabel(beat),
                )
              )
            );
          }
        }
        if(points.length < 2) {
          return ValueListenableBuilder(
            valueListenable: Settings.notifier,
            builder: (context, settings, child) {
              return Graph(
                key: const ValueKey('ecg-graph-dummy'),
                points: const [],
                minVal: settings.ecgMin,
                maxVal: settings.ecgMax,
                minTS: dummyX,
                maxTS: dummyX + Duration.microsecondsPerSecond,
                offsetFromEnd: true,
                showValLimits: false,
              );
            }
          );
        }
        var maxTS = points.last.x;
        var minTS = min(points.first.x, maxTS - 1_000_000 * 60 * 0.1);

        return Stack(
          children: [
            ValueListenableBuilder(
              valueListenable: Settings.notifier,
              builder: (context, settings, child) {
                return Graph(
                  key: const ValueKey('ecg-graph'),
                  points: points,
                  minVal: settings.ecgMin,
                  maxVal: settings.ecgMax,
                  minTS: minTS,
                  maxTS: maxTS,
                  offsetFromEnd: true,
                  clipX: true,
                  unit: L(context).ecgStreamingGraphUnit,
                  showValLimits: false,
                  ranges: ranges,
                  lines: lines,
                );
              }
            ),
            if(isDevBuild)
              Positioned(
                right: 0,
                bottom: 92,
                child: IconButton(
                  onPressed: () async {
                    var filename = 'ecg-${TimeUtil.timeToStr(DateTime.now())}.bin';
                    var memFile = MemoryFile(length: points.length * (2 + 8));
                    for(var point in points) {
                      memFile.writeInt(point.x.round());
                      memFile.writeInt16(point.y.round());
                    }
                    var bytes = memFile.toUint8List();
                    var uri = await Storage.saveFile(filename, 'application/octet-stream', bytes);
                    if(uri != null)
                      showPopupMsg(context, L(context).exportDone);
                  },
                  icon: const Icon(Icons.save)
                ),
              )
         ],
        );
      },
    );
  }
}
