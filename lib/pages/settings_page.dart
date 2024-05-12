// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../util/settings.dart';
import '../widgets/pad.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => SettingsPageState();
}

class SettingsPageState extends State<StatefulWidget> {
  var formKey = GlobalKey<FormBuilderState>();

  Widget intField(String name, int val) {
    return SizedBox(
      width: 50,
      child: FormBuilderTextField(
        name: name,
        initialValue: val.toString(),
        keyboardType: TextInputType.number,
        validator: FormBuilderValidators.compose([
          FormBuilderValidators.required(),
          FormBuilderValidators.integer()
        ]),
        valueTransformer: (value) => value == null ? null : int.tryParse(value),
      )
    );
  }

  Widget rangeFields(
    String title,
    String name1,
    int val1,
    String name2,
    int val2
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            intField(name1, val1),
            Pad.horizontalSpace,
            const Text('\u2013'),
            Pad.horizontalSpace,
            intField(name2, val2),
          ],
        )
      ]
    );
  }

  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PolarMon'),
      ),
      body: SafeArea(
        child: Padding(
          padding: Pad.all,
          child: FormBuilder(
            key: formKey,
            child: ValueListenableBuilder(
              valueListenable: Settings.notifier,
              builder: (context, settings, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    rangeFields('Custom HR range', 'hrCustomMin', settings.hrCustomMin, 'hrCustomMax', settings.hrCustomMax),
                    const SizedBox(height: 50),
                    rangeFields('ECG range, µV', 'ecgMin', settings.ecgMin, 'ecgMax', settings.ecgMax)
                  ]
                );
              }
            )
          ),
        )
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.save),
        onPressed: () async {
          var state = formKey.currentState;
          if(state == null)
            return;
          if(!state.validate())
            return;
          var val = state.instantValue;
          var settings = Settings.fromJson(val);
          await settings.save();
          Navigator.pop(context);
        },
      )
    );
  }
}
