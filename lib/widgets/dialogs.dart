// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../util/locale_manager.dart';

Future<String?> showSaveDialog({
  required BuildContext context,
  required String title,
  List<String>? suggestions,
  String initialText = ''
}) async {
  return await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      final inputController = TextEditingController();
      inputController.text = initialText;

      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            if(suggestions == null)
              TextField(
                autofocus: true,
                controller: inputController,
                textInputAction: TextInputAction.go,
                decoration: InputDecoration(
                  hintText: '<${L(context).saveDialogUnnamed}>'
                ),
                onSubmitted: (text) {
                  Navigator.of(context).pop(text.trim());
                }
              )
            else
              Autocomplete(
                initialValue: TextEditingValue(text: initialText),
                optionsBuilder: (textEditingValue) {
                  inputController.text = textEditingValue.text;
                  var cmpText = textEditingValue.text.toUpperCase();
                  var options = suggestions.where((s) => s.toUpperCase().contains(cmpText));
                  return options;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    autofocus: true,
                    focusNode: focusNode,
                    controller: textEditingController,
                    textInputAction: TextInputAction.go,
                    decoration: InputDecoration(
                      hintText: '<${L(context).saveDialogUnnamed}>'
                    ),
                    onSubmitted: (text) {
                      Navigator.of(context).pop(text);
                    }
                  );
                },
              )
          ]
        ),
        actions: [
          TextButton(
            child: Text(L(context).saveDialogOk),
            onPressed: () {
              Navigator.of(context).pop(inputController.text);
            }
          )
        ]
      );
    }
  );
}

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String text
}) async {
  var result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            child: Text(L(context).confirmDialogNo),
            onPressed: () => Navigator.of(context).pop(false)
          ),
          TextButton(
            child: Text(L(context).confirmDialogYes),
            onPressed: () => Navigator.of(context).pop(true)
          )
        ]
      );
    }
  );
  return result ?? false;
}

void showPopupMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text)
  ));
}
