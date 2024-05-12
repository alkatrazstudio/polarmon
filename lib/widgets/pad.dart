// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

abstract class Pad {
  static const double pad = 5;

  static EdgeInsets get all => const EdgeInsets.all(pad);
  static EdgeInsets get horizontal => const EdgeInsets.symmetric(horizontal: pad);
  static EdgeInsets get vertical => const EdgeInsets.symmetric(vertical: pad);

  static EdgeInsets get left => const EdgeInsets.only(left: pad);
  static EdgeInsets get right => const EdgeInsets.only(right: pad);
  static EdgeInsets get top => const EdgeInsets.only(top: pad);
  static EdgeInsets get bottom => const EdgeInsets.only(bottom: pad);

  static SizedBox get horizontalSpace => const SizedBox(width: pad);
  static SizedBox get verticalSpace => const SizedBox(height: pad);
}
