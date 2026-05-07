import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';
import 'storage_service.dart';
import 'audio_service.dart';
import 'ar_service.dart';
import 'ai_service.dart';

class ServiceLocator {
  static late ApiService apiService;
  static late StorageService storageService;
  static late AudioService audioService;
  static late ARService arService;
  static late AIService aiService;

  static Future<void> init() async {
    await _registerHiveAdapters();
    storageService = await StorageService.init();
    apiService = ApiService();
    audioService = AudioService();
    arService = ARService();
    aiService = AIService();
  }

  static Future<void> _registerHiveAdapters() async {
    await Hive.openBox('scanned_objects');
    await Hive.openBox('settings');
    await Hive.openBox('cache');
  }
}
