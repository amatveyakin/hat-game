import 'package:flutter/material.dart';
import 'package:hatgame/built_value/game_config.dart';
import 'package:hatgame/db/db_columns.dart';
import 'package:hatgame/util/invalid_operation.dart';
import 'package:hatgame/util/local_str.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unicode/unicode.dart' as unicode;

// =============================================================================
// Local config interface

// TODO: Also sync to personal account when it exists.
abstract class LocalStorage {
  static late LocalStorage instance;

  static Future<void> init() async {
    try {
      instance = await LocalStorageFromSharedPreferences.getInstance();
      debugPrint('Local storage loaded successfully.');
    } catch (e) {
      // TODO: Firebase log.
      debugPrint("Couldn't initialize local storage!");
      debugPrint('The error was: $e');
      instance = LocalStorageInMemory();
    }
  }

  // ignore: non_constant_identifier_names
  static void test_init() {
    debugPrint("LocalStorage running in test mode.");
    instance = LocalStorageInMemory();
  }

  T? get<T>(DBColumn<T> column) {
    try {
      return getImpl(column);
    } catch (e) {
      // Can happen after config format changes, e.g. adding required field.
      // TODO: Firebase log.
      debugPrint('Warning: cannot read "${column.name}" from LocalStorage: $e');
      return null;
    }
  }

  Future<void> set<T>(DBColumn<T> column, T data);

  @protected
  T getImpl<T>(DBColumn<T> column);
}

// =============================================================================
// Columns

class LocalColPlayerName extends DBColumn<String?> with DBColSerializeStringOr {
  @override
  String get name => 'player_name';
}

class LocalColLastConfig extends DBColumn<GameConfig?>
    with DBColSerializeBuiltValueOr {
  @override
  String get name => 'last_config';
}

class LocalColLocale extends DBColumn<String?> with DBColSerializeStringOr {
  @override
  String get name => 'locale';
}

// =============================================================================
// Helpers

InvalidOperation? checkPlayerName(String name) {
  if (name.isEmpty) {
    return InvalidOperation(LocalStr.tr('player_name_is_empty'));
  }
  if (name.length > 50) {
    return InvalidOperation(LocalStr.tr('player_name_too_long'));
  }
  for (final c in name.codeUnits) {
    if (unicode.isControl(c) || unicode.isFormat(c)) {
      return InvalidOperation(LocalStr.tr(
          'player_name_contains_invalid_character',
          namedArgs: {'char': String.fromCharCode(c), 'code': c.toString()}));
    }
  }
  return null;
}

// =============================================================================
// Local config implementations

class LocalStorageFromSharedPreferences extends LocalStorage {
  // SharedPreferences cache value themselves, no need to do it on top.
  final SharedPreferences prefs;

  static Future<LocalStorageFromSharedPreferences> getInstance() async {
    return LocalStorageFromSharedPreferences._(
        await SharedPreferences.getInstance());
  }

  LocalStorageFromSharedPreferences._(this.prefs);

  @override
  T getImpl<T>(DBColumn<T> column) {
    return column.deserialize(prefs.getString(column.name));
  }

  @override
  Future<void> set<T>(DBColumn<T> column, T data) async {
    if (data == null) {
      await prefs.remove(column.name);
    } else {
      await prefs.setString(column.name, column.serialize(data)!);
    }
  }
}

class LocalStorageInMemory extends LocalStorage {
  final _data = <String, String?>{};

  @override
  T getImpl<T>(DBColumn<T> column) {
    return column.deserialize(_data[column.name]);
  }

  @override
  Future<void> set<T>(DBColumn<T> column, T data) async {
    _data[column.name] = column.serialize(data);
  }
}
