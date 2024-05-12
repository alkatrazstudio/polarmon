// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

class HrDisplay extends StatelessWidget {
  const HrDisplay({
    required this.hrStream
  });

  final Stream<int>? hrStream;

  @override
  Widget build (context) {
    return StreamBuilder(
      stream: hrStream,
      builder: (context, snapshot) {
        var hr = snapshot.data ?? 0;
        return Row(
          children: [
            Icon(
              Icons.monitor_heart,
              color: hr != 0 ? Colors.red : Theme.of(context).disabledColor,
              size: 50,
            ),
            SizedBox(
              width: 80,
              child: Text(
                '$hr',
                style: const TextStyle(
                  fontSize: 35
                )
              )
            )
          ]
        );
      },
    );
  }
}
