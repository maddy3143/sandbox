import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

class ARService {
  static const MethodChannel _channel =
      MethodChannel('ar_object_scanner/ar_service');

  bool _isInitialized = false;
  bool _isPlaneDetectionActive = false;
  String? _currentSessionId;

  Future<bool> initialize() async {
    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      return _isInitialized;
    } catch (_) {
      return false;
    }
  }

  Future<void> startPlaneDetection() async {
    if (!_isInitialized) return;
    await _channel.invokeMethod('startPlaneDetection');
    _isPlaneDetectionActive = true;
  }

  Future<void> stopPlaneDetection() async {
    await _channel.invokeMethod('stopPlaneDetection');
    _isPlaneDetectionActive = false;
  }

  Future<String> createARSession({required String objectId}) async {
    final sessionId = await _channel.invokeMethod<String>(
      'createSession',
      {'objectId': objectId},
    );
    _currentSessionId = sessionId ?? '';
    return _currentSessionId!;
  }

  Future<void> placeObject({
    required String modelUrl,
    required Vector3 position,
    required double scale,
  }) async {
    await _channel.invokeMethod('placeObject', {
      'modelUrl': modelUrl,
      'position': [position.x, position.y, position.z],
      'scale': scale,
    });
  }

  Future<void> showAROverlay({
    required String label,
    required Vector3 position,
    required String type,
  }) async {
    await _channel.invokeMethod('showOverlay', {
      'label': label,
      'position': [position.x, position.y, position.z],
      'type': type,
    });
  }

  Future<void> highlightComponent({
    required String componentId,
    required List<double> color,
  }) async {
    await _channel.invokeMethod('highlightComponent', {
      'componentId': componentId,
      'color': color,
    });
  }

  Future<Map<String, double>> measureDistance({
    required Vector3 pointA,
    required Vector3 pointB,
  }) async {
    final result = await _channel.invokeMethod<Map>('measureDistance', {
      'pointA': [pointA.x, pointA.y, pointA.z],
      'pointB': [pointB.x, pointB.y, pointB.z],
    });
    return Map<String, double>.from(result ?? {});
  }

  Future<void> clearARScene() async {
    await _channel.invokeMethod('clearScene');
  }

  Future<void> dispose() async {
    await clearARScene();
    _isInitialized = false;
    _currentSessionId = null;
  }

  bool get isInitialized => _isInitialized;
  bool get isPlaneDetectionActive => _isPlaneDetectionActive;
  String? get currentSessionId => _currentSessionId;
}
