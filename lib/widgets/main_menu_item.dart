// SPDX-License-Identifier: MPL-2.0

import 'package:flutter/material.dart';

class MainMenuItem {
  const MainMenuItem(this.title, this.icon, this.onSelected);

  final String title;
  final IconData icon;
  final void Function() onSelected;
}

class MainMenu extends StatelessWidget {
  const MainMenu({
    required this.items
  });

  final List<MainMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MainMenuItem>(
      onSelected: (item) {
        item.onSelected();
      },
      itemBuilder: (context) {
        return items.map((item) => PopupMenuItem<MainMenuItem>(
          value: item,
          child: ListTile(
            leading: Icon(item.icon),
            title: Text(item.title)
          )
        )).toList();
      }
    );
  }
}
