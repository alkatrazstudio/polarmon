// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../util/locale_manager.dart';

abstract class TimeUtil {
  static final dateFormat = DateFormat('yyyyMMddHHmmss');
  static final timestampParser = RegExp(r'^(?<y>\d\d\d\d)(?<M>\d\d)(?<d>\d\d)(?<h>\d\d)(?<m>\d\d)(?<s>\d\d)$'); // DateFormat.parse does not work

  static timeToStr(DateTime date) {
    var dateStr = dateFormat.format(date.toUtc());
    return dateStr;
  }

  static DateTime? strToTime(String dateStr) {
    var match = timestampParser.firstMatch(dateStr);
    if(match == null)
      return null;
    var timestamp = DateTime.utc(
      int.parse(match.namedGroup('y')!),
      int.parse(match.namedGroup('M')!),
      int.parse(match.namedGroup('d')!),
      int.parse(match.namedGroup('h')!),
      int.parse(match.namedGroup('m')!),
      int.parse(match.namedGroup('s')!)
    );
    return timestamp;
  }

  static String durationStr(Duration duration) {
    var secs = duration.inSeconds;
    var mins = (secs / 60).floor();
    secs = secs - mins * 60;
    if(mins < 60)
      return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    var hrs = (mins / 60).floor();
    mins = mins - hrs * 60;
    return '$hrs:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static String durationToHumanStr(Duration duration, BuildContext context) {
    var secs = duration.inSeconds;
    if(secs < 60)
      return L(context).timeUtilS(secs: secs);
    var mins = (secs / 60).floor();
    secs = secs - mins * 60;
    if(mins < 60)
      return L(context).timeUtilMS(mins: mins, secs: secs.toString().padLeft(2, '0'));
    var hrs = (mins / 60).floor();
    mins = mins - hrs * 60;
    return L(context).timeUtilHMS(hours: hrs, mins: mins.toString().padLeft(2, '0'), secs: secs.toString().padLeft(2, '0'));
  }
}
