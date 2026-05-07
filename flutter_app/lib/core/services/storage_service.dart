import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  late final Box _objectsBox;
  late final Box _settingsBox;
  late final Box _cacheBox;

  StorageService._internal({
    required Box objectsBox,
    required Box settingsBox,
    required Box cacheBox,
  }) : _objectsBox = objectsBox,
       _settingsBox = settingsBox,
       _cacheBox = cacheBox;

  static Future<StorageService> init() async {
    final objectsBox = Hive.box('scanned_objects');
    final settingsBox = Hive.box('settings');
    final cacheBox = Hive.box('cache');
    return StorageService._internal(
      objectsBox: objectsBox,
      settingsBox: settingsBox,
      cacheBox: cacheBox,
    );
  }

  Future<void> saveScannedObject(Map<String, dynamic> objectData) async {
    final id = objectData['id'] as String;
    objectData['saved_at'] = DateTime.now().toIso8601String();
    await _objectsBox.put(id, jsonEncode(objectData));
  }

  Map<String, dynamic>? getScannedObject(String id) {
    final data = _objectsBox.get(id);
    if (data == null) return null;
    return jsonDecode(data as String) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> getAllScannedObjects() {
    return _objectsBox.values
        .map((v) => jsonDecode(v as String) as Map<String, dynamic>)
        .toList()
      ..sort((a, b) => (b['saved_at'] as String).compareTo(
        a['saved_at'] as String,
      ));
  }

  Future<void> deleteScannedObject(String id) async {
    await _objectsBox.delete(id);
  }

  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> setSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  Future<void> cacheData(
    String key,
    Map<String, dynamic> data, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final cacheEntry = {
      'data': data,
      'expires_at': DateTime.now().add(ttl).toIso8601String(),
    };
    await _cacheBox.put(key, jsonEncode(cacheEntry));
  }

  Map<String, dynamic>? getCachedData(String key) {
    final raw = _cacheBox.get(key);
    if (raw == null) return null;

    final entry = jsonDecode(raw as String) as Map<String, dynamic>;
    final expiresAt = DateTime.parse(entry['expires_at'] as String);

    if (DateTime.now().isAfter(expiresAt)) {
      _cacheBox.delete(key);
      return null;
    }

    return entry['data'] as Map<String, dynamic>;
  }

  Future<void> clearCache() async {
    await _cacheBox.clear();
  }
}
