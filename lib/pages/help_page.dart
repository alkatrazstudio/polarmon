// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:help_page/help_page.dart';

const _manualHtml = '''
<ul>
<li>Only Polar H10 devices are supported.</li>
<li>Bluetooth and location needs to be enabled in Android
  (PolarMon does not actually uses the location feature by itself, but it's needed to connect to the device).</li>
<li>PolarMon automatically connects to the first available Polar H10 device.</li>
<li>If the device fails to connect, try to remove it from Android Bluetooth devices and restart PolarMon.</li>
<li>The header of the main page displays the battery level and the device ID.</li>
<li>Scroll and scale the graphs horizontally by using the area with the
  <widget name="scroll_area_1"></widget><widget name="scroll_area_2"></widget><widget name="scroll_area_3"></widget>
  icon.</li>
<li>The graph starts scrolling automatically when you scroll it to its rightmost position (which is the default).</li>
<li>Touch the graph to see the exact point value.</li>
<li>Press the <widget name="hr_range_1"></widget>/<widget name="hr_range_2"></widget> on the right side of the graph
  to toggle between the custom HR range and the actual min/max range.</li>
<li>The ECG values are in microvolts.</li>
<li>The realtime graphs are not updated while PolarMon is minimized or closed,
  use the recording feature to save the HR graph.</li>
<li>Access the list of recordings by tapping on <widget name="menu"></widget> in the top left corner.</li>
<li>You can rename or remove a recording on its page.</li>
<li><widget name="bookmark"></widget> - add a bookmark.</li>
<li><widget name="bookmark_range_start"></widget> - add a bookmark for an interval
  (mark the end of the interval by tapping the <widget name="bookmark_range_end"></widget> button).</li>
</ul>
''';
Map<String, Widget> _manualHtmlWidgets = {
  'scroll_area_1': const Icon(Icons.keyboard_double_arrow_left),
  'scroll_area_2': const Icon(Icons.touch_app),
  'scroll_area_3': const Icon(Icons.keyboard_double_arrow_right),
  'hr_range_1': const Icon(Icons.unfold_more),
  'hr_range_2': const Icon(Icons.unfold_less),
  'menu': const Icon(Icons.menu),
  'bookmark': const Icon(Icons.bookmark_add),
  'bookmark_range_start': const Icon(Icons.start),
  'bookmark_range_end': Transform.rotate(
    angle: pi/2,
    child: const Icon(Icons.vertical_align_top),
  )
};

Future<void> openHelpPage(BuildContext context) async {
  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (context) => HelpPage(
      appTitle: 'PolarMon',
      githubAuthor: 'alkatrazstudio',
      githubProject: 'polarmon',
      manualHtml: _manualHtml,
      manualHtmlWidgets: _manualHtmlWidgets,
      license: HelpPageLicense.mpl,
      libraries: [
        const HelpPagePackage(
          name: 'Polar SDK',
          url: 'https://github.com/polarofficial/polar-ble-sdk',
          licenseName: 'Polar SDK License',
          licenseUrl: 'https://raw.githubusercontent.com/polarofficial/polar-ble-sdk/master/Polar_SDK_License.txt'
        ),
        HelpPagePackage.flutter('polar', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('fl_chart', HelpPageLicense.mit),
        HelpPagePackage.flutter('wakelock_plus', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('intl', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('path_provider', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('collection', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('flutter_form_builder', HelpPageLicense.mit),
        HelpPagePackage.flutter('form_builder_validators', HelpPageLicense.bsd3)
      ],
      assets: const [],
    ))
  );
}
