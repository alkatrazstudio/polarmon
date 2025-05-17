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

extension PadAround on Widget {
  Padding pad(EdgeInsets padding) {
    return Padding(
      padding: padding,
      child: this,
    );
  }

  Padding get padAll => pad(Pad.all);
  Padding get padHorizontal => pad(Pad.horizontal);
  Padding get padVertical => pad(Pad.vertical);
  Padding get padLeft => pad(Pad.left);
  Padding get padRight => pad(Pad.right);
  Padding get padTop => pad(Pad.top);
  Padding get padBottom => pad(Pad.bottom);
}
