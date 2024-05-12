// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

import '../util/device.dart';
import '../util/settings.dart';
import '../widgets/graph.dart';

class EcgStreamingGraph extends StatefulWidget {
  const EcgStreamingGraph({
    required this.stream
  });

  final Stream<Iterable<EcgSample>> stream;

  @override
  State<EcgStreamingGraph> createState() => _EcgStreamingGraphState();
}

class _EcgStreamingGraphState extends State<EcgStreamingGraph> {
  final List<FlSpot> points = [];

  var dummyX = DateTime.now().microsecondsSinceEpoch;

  @override
  Widget build(context) {
    return StreamBuilder(
      stream: widget.stream,
      builder: (context, snapshot) {
        var samples = snapshot.data;
        if(samples != null)
          points.addAll(samples.map((sample) => FlSpot(sample.timestamp.microsecondsSinceEpoch.toDouble(), sample.voltage.toDouble())));
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
        var minTS = min(points.first.x, maxTS - 1000000 * 60 * 0.1);

        return ValueListenableBuilder(
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
              unit: 'µV',
              showValLimits: false,
            );
          }
        );
      },
    );
  }
}
