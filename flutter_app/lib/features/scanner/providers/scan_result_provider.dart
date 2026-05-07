import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_locator.dart';
import '../../../shared/models/scanned_object.dart';

final scanResultProvider = FutureProvider.family<ScannedObject?, String>(
  (ref, objectId) async {
    final data = ServiceLocator.storageService.getScannedObject(objectId);
    if (data == null) return null;
    return ScannedObject.fromJson(data);
  },
);
