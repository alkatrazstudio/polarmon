// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

import '../util/locale_manager.dart';

class SearchField extends StatefulWidget {
  const SearchField({
    required this.onChanged
  });

  final void Function(String) onChanged;

  @override
  State<SearchField> createState() => SearchFieldState();
}

class SearchFieldState extends State<SearchField> {
  final controller = TextEditingController();

  @override
  Widget build(context) {
    return TextField(
      onChanged: (text) {
        widget.onChanged(text);
      },
      controller: controller,
      decoration: InputDecoration(
        hintText: L(context).searchFieldHint,
        contentPadding: const EdgeInsets.all(10),
        suffixIcon: IconButton(
          onPressed: () {
            controller.clear();
            widget.onChanged('');
          },
          icon: const Icon(Icons.clear)
        )
      ),
    );
  }
}
