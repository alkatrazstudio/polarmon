// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../util/mark_manager.dart';
import '../util/settings.dart';
import '../util/time_util.dart';

class Graph extends StatefulWidget {
  Graph({
    super.key,
    required this.points,
    required num minVal,
    required num maxVal,
    required num minTS,
    required num maxTS,
    required this.offsetFromEnd,
    this.clipX = false,
    this.marks = const [],
    this.unit = '',
    this.showValLimits = true,
    this.customRangeIsUsed
  }):
    minVal = minVal.toDouble(),
    maxVal = maxVal.toDouble(),
    minTS = minTS.toDouble(),
    maxTS = maxTS.toDouble(),
    yGridInterval = max(1, ((maxVal - minVal) / yGridSteps).roundToDouble());

  static const xGridSteps = 4;
  static const yGridSteps = 4;

  final List<FlSpot> points;
  final double minVal;
  final double maxVal;
  final double minTS;
  final double maxTS;
  final bool offsetFromEnd;
  final bool clipX;
  final List<Mark> marks;
  final String unit;
  final double yGridInterval;
  final bool showValLimits;
  final bool? customRangeIsUsed;

  @override
  State<Graph> createState() => _GraphState();
}

class _GraphState extends State<Graph> {
  late double winMinTS;
  late double winMaxTS;
  double initWinMinTS = 0;
  double initWinMaxTS = 0;
  bool follow = true;

  @override
  void initState() {
    super.initState();
    winMinTS = widget.minTS;
    winMaxTS = widget.maxTS;
  }

  String topLabel(double x) {
    var ts = x.round();
    var label = DateFormat.Hms().format(DateTime.fromMicrosecondsSinceEpoch(ts));
    return label;
  }

  String bottomLabel(double x) {
    var ts = x.round();
    var offsetStr = widget.offsetFromEnd
      ? TimeUtil.durationStr(Duration(microseconds: (widget.maxTS - ts).round()))
      : TimeUtil.durationStr(Duration(microseconds: (ts - widget.minTS).round()));
    var label = '${widget.offsetFromEnd ? '-' : '+'}$offsetStr';
    return label;
  }

  Alignment markLabelAlignment(Mark mark) {
    if(mark.startAt.microsecondsSinceEpoch > ((winMaxTS - winMinTS) / 2 + winMinTS)) {
      return Alignment.topLeft;
    } else {
      return Alignment.topRight;
    }
  }

  Widget chart() {
    var xGridInterval = (winMaxTS - winMinTS) / Graph.xGridSteps;
    if(follow) {
      var tsDiff = winMaxTS - winMinTS;
      winMaxTS = widget.maxTS;
      winMinTS = winMaxTS - tsDiff;
    }

    List<FlSpot> shownPoints;
    if(widget.clipX) {
      shownPoints = widget.points;
    } else {
      shownPoints = widget.points.where((point) => point.x >= winMinTS && point.x <= winMaxTS).toList();
    }

    var lineBarData = LineChartBarData(
      spots: shownPoints,
      dotData: const FlDotData(
        show: false,
      )
    );

    return LineChart(
      duration: Duration.zero,
      LineChartData(
        rangeAnnotations: RangeAnnotations(
          verticalRangeAnnotations: widget.marks.where((mark) => mark.endAt != null).map(
            (mark) => VerticalRangeAnnotation(
              x1: mark.startAt.microsecondsSinceEpoch.toDouble(),
              x2: mark.endAt!.microsecondsSinceEpoch.toDouble(),
              color: Colors.blue.withAlpha(64)
            )
          ).toList()
        ),
        extraLinesData: ExtraLinesData(
          verticalLines: widget.marks.map(
            (mark) => VerticalLine(
              x: mark.startAt.microsecondsSinceEpoch.toDouble(),
              color: Colors.blue,
              strokeWidth: 1,
              label: VerticalLineLabel(
                alignment: markLabelAlignment(mark),
                show: true,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  backgroundColor: Colors.black,
                ),
                labelResolver: (line) => '\u{00A0}${mark.title}\u{00A0}',
              )
            )
          ).toList()
        ),
        clipData: widget.clipX ? const FlClipData.all() : const FlClipData.vertical(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            getTooltipItems: (spots) {
              var spot = spots.first;
              var label1 = topLabel(spot.x);
              var label2 = bottomLabel(spot.x);
              var val = spot.y.round();
              var valWithUnit = widget.unit.isNotEmpty ? '$val ${widget.unit}' : '$val';
              var label = '$valWithUnit\n$label1\n[$label2]';
              return [
                LineTooltipItem(
                  label,
                  const TextStyle()
                )
              ];
            }
          ),
        ),
        minX: winMinTS,
        maxX: winMaxTS,
        minY: widget.minVal,
        maxY: widget.maxVal,
        gridData: FlGridData(
          show: true,
          verticalInterval: xGridInterval,
          horizontalInterval: widget.yGridInterval
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: widget.yGridInterval,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                var label = '${value.round()}';
                if(meta.axisPosition == 0 || meta.axisPosition >= meta.parentAxisSize) {
                  if(widget.showValLimits) {
                    return Transform.translate(
                      offset: const Offset(30, 0),
                      child: Text(label)
                    );
                  }
                  return const SizedBox.shrink();
                }
                return Text(label);
              }
            )
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: xGridInterval,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                var label = topLabel(value);
                if(meta.axisPosition == 0)
                  return FractionalTranslation(
                    translation: const Offset(0.5, 0),
                    child: Text(label)
                  );
                if(meta.axisPosition >= meta.parentAxisSize)
                  return FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Text(label)
                  );
                return Text('\n$label');
              },
            )
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: xGridInterval,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                var label = bottomLabel(value);
                if(meta.axisPosition == 0)
                  return FractionalTranslation(
                    translation: const Offset(0.5, 0),
                    child: Text('\n$label')
                  );
                if(meta.axisPosition >= meta.parentAxisSize) {
                  return FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: Text('\n$label')
                  );
                }
                return Text(label);
              },
            )
          )
        ),
        lineBarsData: [
          lineBarData
        ]
      )
    );
  }

  Widget dragHandle() {
    return ColoredBox(
      color: Colors.blueGrey,
      child: SizedBox(
        width: double.infinity,
        height: 100,
        child: Stack(
          children: [
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_double_arrow_left),
                  Icon(Icons.touch_app),
                  Icon(Icons.keyboard_double_arrow_right)
                ]
              )
            ),
            GestureDetector(
              onScaleStart: (details) {
                if(details.pointerCount == 2) {
                  initWinMinTS = winMinTS;
                  initWinMaxTS = winMaxTS;
                }
              },
              onScaleUpdate: (details) {
                if(details.pointerCount == 1) {
                  var curDiff = winMaxTS - winMinTS;
                  var offset = curDiff * -details.focalPointDelta.dx / 100;
                  var newWinMinTS = winMinTS + offset;
                  var newWinMaxTS = winMaxTS + offset;
                  if(offset > 0) {
                    newWinMaxTS = min(widget.maxTS, newWinMaxTS);
                    newWinMinTS = newWinMaxTS - curDiff;
                  } else {
                    newWinMinTS = max(widget.minTS, newWinMinTS);
                    newWinMaxTS = newWinMinTS + curDiff;
                  }
                  setState(() {
                    winMinTS = newWinMinTS;
                    winMaxTS = newWinMaxTS;
                    follow = false;
                  });
                  return;
                }

                if(details.pointerCount == 2) {
                  var newDiff = (initWinMaxTS - initWinMinTS) * (1 / details.horizontalScale) / 2;
                  var centerTS = (initWinMaxTS - initWinMinTS) / 2 + initWinMinTS;
                  var newWinMinTS = max(widget.minTS, centerTS - newDiff);
                  var newWinMaxTS = min(widget.maxTS, centerTS + newDiff);
                  setState(() {
                    winMinTS = newWinMinTS;
                    winMaxTS = newWinMaxTS;
                    follow = false;
                  });
                  return;
                }
              },
              onScaleEnd: (details) {
                if(winMaxTS == widget.maxTS) {
                  setState(() {
                    follow = true;
                  });
                }
              }
            )
          ]
        )
      )
    );
  }

  @override
  Widget build(context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.25,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Stack(
                children: [
                  chart(),
                  if(widget.customRangeIsUsed != null)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () {
                            Settings(hrCustomEnable: widget.customRangeIsUsed == false).save();
                          },
                          icon: Icon(widget.customRangeIsUsed! ? Icons.unfold_less : Icons.unfold_more)
                        )
                      ),
                    )
                ],
              ),
              if(widget.points.isEmpty)
                const CircularProgressIndicator()
            ]
          )
        ),
        dragHandle()
      ]
    );
  }
}
