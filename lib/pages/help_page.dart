// SPDX-License-Identifier: MPL-2.0

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:help_page/help_page.dart';
import 'package:intl/intl.dart';

const _manualHtmlEn = '''
<ul>
<li>Only Polar H10 devices are supported.</li>
<li>Bluetooth and location needs to be enabled in Android
  (PolarMon does not actually uses the location feature by itself, but it's needed to connect to the device).</li>
<li>PolarMon automatically connects to the first available Polar H10 device.</li>
<li>If the device fails to connect, try to remove it from Android Bluetooth devices and restart PolarMon.</li>
<li>The header of the main page displays the battery level and the device ID.</li>
<li>Scroll and scale the graphs horizontally by using the area with the <widget name="scroll_area"> icon.</li>
<li>The graph starts scrolling automatically when you scroll it manually to its rightmost position (which is the default).</li>
<li>Touch the graph to see the exact values at the selected timestamp.</li>
<li>Press the <kbd><widget name="hr_range_1"></widget>/<widget name="hr_range_2"></widget></kbd> on the right side of the graph
  to toggle between the custom HR range and the actual min/max range of the current values.</li>
<li>The ECG values are in microvolts.</li>
<li>The realtime graphs are not updated while PolarMon is minimized or closed,
  use the recording feature to save the whole HR graph.</li>
<li>Access the list of recordings by tapping on <widget name="menu"></widget> in the top left corner.</li>
<li>You can search the recordings in the list by name or date (date or time should be entered manually into the search field).</li>
<li>You can rename or remove a recording on its page, which you can open by tapping on the recording in the list.</li>
<li>In case PolarMon is stuck when saving a recording (keeps saving for more than one minute),
  restart the application and trye to save the recording again or remove it from the device using the
  <widget name="remove_recording"></widget> button.</li>
<li><widget name="bookmark"></widget> - add a bookmark to the graph.</li>
<li><widget name="bookmark_range_start"></widget> - add a bookmark for an interval
  (mark the end of the interval by tapping the <widget name="bookmark_range_end"></widget> button).</li>
</ul>
''';
const _manualHtmlRu = '''
<ul>
<li>Поддерживаются только устройства Polar H10.</li>
<li>В настройках Android должны быть включёны Bluetooth и местоположение
  (PolarMon не использует определение местоположения, но оно нужно для подсоединения к устройству).</li>
<li>PolarMon автоматом подсоединяется к первому доступному устройству Polar H10.</li>
<li>При ошибке соединения попробуйте убрать устройство из списка устройств Blutooth и перезапустите PolarMon.</li>
<li>Заголовок главной страницы приложения показывает уровень батареи и ID устройства.</li>
<li>Прокручивайте и масштабируйте график по горизонтали, используя зону с иконкой <widget name="scroll_area"></widget>.</li>
<li>График начинает прокручиваться автоматом, если его прокрутить вручную до самой правой позиции (где он и находится изначально).</li>
<li>Дотроньтесь до графика, чтобы увидеть точные значения в нужной точке времени.</li>
<li>Нажмите <widget name="hr_range_1"></widget>/<widget name="hr_range_2"></widget> справа от графика,
  чтобы переключиться между диапазоном пульса, заданным в настройках, и реальным диапазоном текущих значений.</li>
<li>Значения ЭКГ указаны в микровольтах.</li>
<li>Значения не добавляются на график, пока PolarMon свёрнут или закрыт,
  поэтому используйте функционал записи, чтобы сохранить полный график пульса.</li>
<li>Для доступа к списку записей нажмите на <widget name="menu"></widget> в верхнем левом углу.</li>
<li>Записи в списке можно искать по названию или дате (дату и время надо вводить вручную в поле поиска).</li>
<li>Переименовать или удалить запись можно на её странице, которую можно открыть, нажав на запись в списке.</li>
<li>Если PolarMon завис в процессе сохранения записи (сохраняет больше минуты),
  перезапустите приложение и попробуйте сохранить запись заново или удалите её с устройства, нажав на кнопку
  <widget name="remove_recording"></widget>.</li>
<li><widget name="bookmark"></widget> - добавить отметку на график.</li>
<li><widget name="bookmark_range_start"></widget> - добавить отметку для интервала
  (конец интервала можно пометить, нажав на кнопку <widget name="bookmark_range_end"></widget>).</li>
</ul>
''';
Map<String, Widget> _manualHtmlWidgets = {
  'scroll_area': Row(
    children: const [
      Icon(Icons.keyboard_double_arrow_left),
      Icon(Icons.touch_app),
      Icon(Icons.keyboard_double_arrow_right)
    ],
  ),
  'hr_range_1': const Icon(Icons.unfold_more),
  'hr_range_2': const Icon(Icons.unfold_less),
  'menu': const Icon(Icons.menu),
  'bookmark': const Icon(Icons.bookmark_add),
  'bookmark_range_start': const Icon(Icons.start),
  'bookmark_range_end': Transform.rotate(
    angle: pi/2,
    child: const Icon(Icons.vertical_align_top),
  ),
  'remove_recording': const Icon(Icons.delete_forever),
};

Future<void> openHelpPage(BuildContext context) async {
  var manualHtml = switch(Intl.getCurrentLocale()) {
    'ru' => _manualHtmlRu,
    _ => _manualHtmlEn
  };

  await Navigator.push<void>(
    context,
    MaterialPageRoute(builder: (context) => HelpPage(
      appTitle: 'PolarMon',
      githubAuthor: 'alkatrazstudio',
      githubProject: 'polarmon',
      manualHtml: manualHtml,
      manualHtmlWidgets: _manualHtmlWidgets,
      license: HelpPageLicense.mpl2,
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
        HelpPagePackage.flutter('form_builder_validators', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('path', HelpPageLicense.bsd3),
        HelpPagePackage.flutter('flutter_foreground_task', HelpPageLicense.mit),
      ],
      assets: const [],
    ))
  );
}
