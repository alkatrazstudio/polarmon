// SPDX-License-Identifier: MPL-2.0

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import '../util/file_util.dart';

class AutocompleteStore {
  AutocompleteStore(this.filename);

  String filename;
  List<String>? _items;
  Future<List<String>>? _itemsFuture;

  static const maxItems = 100;

  Future<File> file() async {
    var file = await FileUtil.file(filename);
    return file;
  }

  Future<void> save(List<String> items) async {
    var itemsToSave = <String>[];
    for(var item in items) {
      var upperTitle = item.toUpperCase();
      if(itemsToSave.firstWhereOrNull((s) => s.toUpperCase() == upperTitle) != null)
        continue;
      itemsToSave.add(item);
      if(itemsToSave.length == maxItems)
        break;
    }

    try {
      await FileUtil.writeJsonSafe(await file(), itemsToSave);
    } catch(e) {
      //
    }

    _items = itemsToSave;
    _itemsFuture = null;
  }

  Future<void> add(String item) async {
    item = item.trim();
    if(item.isEmpty)
      return;
    var titles = [item, ...await load()];
    await save(titles);
  }

  Future<List<String>> _load() async {
    try {
      var json = await (await file()).readAsString();
      var rawItems = jsonDecode(json) as List<dynamic>;
      var items = rawItems.cast<String>();
      return items;
    } catch(e) {
      return [];
    }
  }

  Future<List<String>> load() async {
    if(_items != null)
      return _items!;
    _itemsFuture ??= _load();
    return _itemsFuture!;
  }
}
