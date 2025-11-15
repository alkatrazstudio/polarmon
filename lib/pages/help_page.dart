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

<h3>Irregular heartbeat detection</h3>
<p>
  The ECG will show detected irregular heartbeats with red lines.
  This is an experimental feature, may not work correctly or at all.
</p>
<p>
  Each irregular heartbeat will be marked with one or more abbreviated comments.
  The list of possible comments is as follows:
</p>
<ul>
  <li>"L" - the heartbeat interval is much longer than usual</li>
  <li>"R▲" - the R peak is much higher than usual</li>
  <li>"S▲" - the S peak is much higher than usual</li>
  <li>"R▼" - the R peak is much lower than usual</li>
  <li>"S▼" - the S peak is much lower than usual</li>
  <li>"S0L" - the recovery from S peak to zero is much longer than usual</li>
  <li>"RR" - more than one R slope at a time (the R slope has one or more notches)</li>
</ul>

<h3>Notification</h3>
<p>
  Polarmon runs as a service in background.
  It displays a notification with some statistics.
</p>
<p>
  The first line of the notification starts with "[elapsed time, h:mm] - [current heart rate]".
  Then info about averages/extremes will be appended in the format of "[period]: [min-median-max]".
  The info about the periods will only show after the amount of time specified in the period has passed.
</p>
<p>
  Example: "1:23 - 76; 10M: 68-72-90; 1H: 66-70-115".
  It means:
</p>
<ul>
<li>the statistics is gathered for 1 hour 23 minutes</li>
<li>the current heart rate is 76 beats per minute</li>
<li>for the past 10 minutes: the minimum heart rate is 68, the median - 72, the maximum - 90</li>
<li>for the past hour: the minimum heart rate is 66, the median - 70, the maximum - 115</li>
</ul>
<p>
  The second line of the notification show the detected irregular heartbeats.
  The heartbeat is considered irregular if it has both R▲ and S0L, or L (see above for explanation).
  The line starts with "[irregular heartbeats count] / [total heartbeats] ([irregular heartbeats rate])".
  Then info about the number of irregular heartbeats per certain period will be shown in the format of "[period]: [irregular heartbeats count]".
  The info about the periods will only show after the amount of time specified in the period has passed.
</p>
<p>
  Example: "40 / 35876 (1 in 897); 10M: 2; 1H: 15; 6H: 28".
  It means:
</p>
<ul>
<li>20 out of 35876 heartbeats were detected as irregular</li>
<li>roughly 1 in each 897 heartbeats are irregular, on average</li>
<li>for the past 10 minutes there were 2 irregular heartbeats</li>
<li>for the past hour there were 15 irregular heartbeats</li>
<li>for the past 6 hours there were 28 irregular heartbeats</li>
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

<h3>Обнаружение аритмии</h3>
<p>
  На графике ЭКГ будут видны зафиксированные признаки аритмии, которые будут отмечены красными линиями.
  Это экспериментальная функция, она может плохо работать или не работать вообще.
</p>
<p>
  Каждый признак аритмии будет отмечен комментарием в виде аббревиатуры.
  Список возможных комментариев:
</p>
<ul>
  <li>"L" - длительность удара сердца значительно больше обычного</li>
  <li>"R▲" - амплитуда зубца R значительно выше обычного</li>
  <li>"S▲" - амплитуда зубца S значительно выше обычного</li>
  <li>"R▼" - амплитуда зубца R значительно ниже обычного</li>
  <li>"S▼" - амплитуда зубца S значительно ниже обычного</li>
  <li>"S0L" - восстановление с пика зубца S до нуля значительно дольше обычного</li>
  <li>"RR" - более одного зубца R подряд</li>
</ul>

<h3>Оповещение</h3>
<p>
  Polarmon работает как сервис на заднем фоне.
  Он показывает оповещение в области оповещений.
  В этом оповещении показывается некоторая статистика.
</p>
<p>
  Первая строка оповещения начинается с "[прошедшее время, ч:мм] - [текущий пульс]".
  Далее будет идти информация о средних и крайних значениях пульса в формате "[период]: [минимум-медиана-максимум]".
  Информация по каждому интервалу будет показана только после того, как пройдёт соответствующее количество времени.
</p>
<p>
  Пример: "1:23 - 76; 10M: 68-72-90; 1H: 66-70-115".
  Это означает:
</p>
<ul>
<li>статистика собрана за 1 час и 23 минуты</li>
<li>текущий пульс - 76 ударов в минуту</li>
<li>за последние 10 минут: минимальный пульс - 68, медиана - 72, максимальный - 90</li>
<li>за последний час: минимальный пульс - 66, медиана - 70, максимальный - 115</li>
</ul>
<p>
  Вторая строка оповещения показывает зафиксированные нарушения сердечного ритма (далее - НСР).
  В контексте Polarmon НСР - это наличие либо R▲ и S0L, либо L (см. описание этих сокращений выше).
  Строка начинается с "[число НСР] / [общее число ударов сердца] ([частота НСР])".
  Далее будет показано число НСР за определённый промежуток времени в формате "[период]: [число НСР]".
  Информация по каждому интервалу будет показана только после того, как пройдёт соответствующее количество времени.
</p>
<p>
  Пример: "40 / 35876 (1 in 897); 10M: 2; 1H: 15; 6H: 28".
  Это означает:
</p>
<ul>
<li>в 20 из 35876 ударах сердца выявлены нарушения</li>
<li>НРС встречаются примерно каждые 897 ударов сердца</li>
<li>за последние 10 минут было 2 НРС</li>
<li>за последний час было 15 НРС</li>
<li>за последние 6 часов было 28 НРС</li>
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
