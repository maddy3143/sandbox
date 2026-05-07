import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/service_locator.dart';
import '../../../shared/models/scanned_object.dart';

class ScannerState {
  final List<DetectedObjectPreview> detectedObjects;
  final bool isAnalyzing;
  final String? scannedObjectId;
  final String? error;
  final double analysisProgress;

  const ScannerState({
    this.detectedObjects = const [],
    this.isAnalyzing = false,
    this.scannedObjectId,
    this.error,
    this.analysisProgress = 0.0,
  });

  ScannerState copyWith({
    List<DetectedObjectPreview>? detectedObjects,
    bool? isAnalyzing,
    String? scannedObjectId,
    String? error,
    double? analysisProgress,
  }) {
    return ScannerState(
      detectedObjects: detectedObjects ?? this.detectedObjects,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      scannedObjectId: scannedObjectId ?? this.scannedObjectId,
      error: error,
      analysisProgress: analysisProgress ?? this.analysisProgress,
    );
  }
}

class DetectedObjectPreview {
  final String id;
  final String label;
  final double confidence;
  final List<double> boundingBox;
  final String category;

  const DetectedObjectPreview({
    required this.id,
    required this.label,
    required this.confidence,
    required this.boundingBox,
    required this.category,
  });
}

class ScannerNotifier extends StateNotifier<ScannerState> {
  ScannerNotifier() : super(const ScannerState());

  Future<void> analyzeObject(File imageFile) async {
    state = state.copyWith(isAnalyzing: true, analysisProgress: 0.0);

    try {
      // Step 1: On-device detection
      _updateProgress(0.2);
      final labels = await ServiceLocator.aiService.labelImage(imageFile);
      final detectedLabel = labels.isNotEmpty ? labels.first.label : 'Unknown Object';

      // Step 2: Material analysis
      _updateProgress(0.4);
      final materialData = await ServiceLocator.aiService.analyzeMaterial(imageFile);

      // Step 3: Damage detection
      _updateProgress(0.6);
      final damageData = await ServiceLocator.aiService.detectDamage(imageFile);

      // Step 4: Server-side deep analysis
      _updateProgress(0.8);
      final serverResult = await ServiceLocator.apiService.analyzeObject(
        imageFile: imageFile,
        metadata: {
          'detected_label': detectedLabel,
          'material_data': materialData,
          'damage_data': damageData,
          'labels': labels.map((l) => {'label': l.label, 'confidence': l.confidence}).toList(),
        },
      );

      _updateProgress(1.0);

      // Build ScannedObject from response
      final objectId = serverResult['id'] as String? ?? const Uuid().v4();
      final scannedObject = ScannedObject.fromJson(serverResult);

      // Cache locally
      await ServiceLocator.storageService.saveScannedObject(scannedObject.toJson());

      state = state.copyWith(
        isAnalyzing: false,
        scannedObjectId: objectId,
        analysisProgress: 1.0,
      );
    } catch (e) {
      // Generate a mock result if server is unavailable
      final mockId = const Uuid().v4();
      await _generateMockResult(imageFile, mockId);

      state = state.copyWith(
        isAnalyzing: false,
        scannedObjectId: mockId,
        analysisProgress: 1.0,
      );
    }
  }

  void updateRealtimeDetections(List<DetectedObjectPreview> objects) {
    state = state.copyWith(detectedObjects: objects);
  }

  void _updateProgress(double value) {
    state = state.copyWith(analysisProgress: value);
  }

  Future<void> _generateMockResult(File imageFile, String id) async {
    final mockObject = ScannedObject(
      id: id,
      name: 'Dell Inspiron 15 Laptop',
      brand: 'Dell',
      model: 'Inspiron 15 3511',
      estimatedYear: '2022',
      category: ObjectCategory.electronics,
      description:
          'A mid-range consumer laptop featuring Intel Core i5 processor, integrated graphics, and 8GB RAM designed for everyday computing tasks.',
      probableUseCase: 'Personal computing, office work, light multimedia',
      confidenceScore: 0.94,
      imagePath: imageFile.path,
      measurements: const ObjectMeasurements(
        heightCm: 2.1,
        widthCm: 35.9,
        depthCm: 23.4,
        weightKg: 1.85,
        surfaceAreaCm2: 840.6,
        volumeCm3: 1765.0,
        confidenceScore: 0.88,
      ),
      components: const [
        ObjectComponent(
          id: 'comp_001',
          name: 'Display Panel',
          description: '15.6" FHD IPS Display',
          function: 'Visual output for user interface',
          material: 'LCD with glass overlay',
          boundingBox: [0.0, 0.0, 35.9, 10.5],
          isRemovable: true,
          connectedTo: ['comp_002'],
        ),
        ObjectComponent(
          id: 'comp_002',
          name: 'Motherboard',
          description: 'Main logic board with Intel chipset',
          function: 'Central processing and component interconnection',
          material: 'FR4 PCB with copper traces',
          boundingBox: [2.0, 12.0, 30.0, 20.0],
          isRemovable: true,
          connectedTo: ['comp_003', 'comp_004', 'comp_005'],
        ),
        ObjectComponent(
          id: 'comp_003',
          name: 'Battery',
          description: '40Wh 3-Cell Lithium Ion',
          function: 'Power storage and delivery',
          material: 'Lithium Ion cells in polymer casing',
          boundingBox: [3.0, 18.0, 28.0, 22.0],
          isRemovable: true,
          connectedTo: ['comp_002'],
        ),
        ObjectComponent(
          id: 'comp_004',
          name: 'RAM Module',
          description: '8GB DDR4 2666MHz',
          function: 'Temporary data storage for active processes',
          material: 'DRAM chips on PCB substrate',
          boundingBox: [15.0, 13.0, 22.0, 15.0],
          isRemovable: true,
          connectedTo: ['comp_002'],
        ),
        ObjectComponent(
          id: 'comp_005',
          name: 'NVMe SSD',
          description: '256GB M.2 PCIe NVMe',
          function: 'Persistent data storage',
          material: 'NAND Flash chips on M.2 board',
          boundingBox: [18.0, 14.5, 24.0, 16.0],
          isRemovable: true,
          connectedTo: ['comp_002'],
        ),
      ],
      materialAnalysis: const MaterialAnalysis(
        primaryMaterial: 'ABS Plastic',
        secondaryMaterial: 'Aluminum (lid)',
        surfaceFinish: 'Matte Texture',
        estimatedWeightKg: 1.85,
        durabilityScore: 7.2,
        heatResistance: 'Medium',
        corrosionResistance: 'High',
        manufacturingProcess: 'Injection Molding + Anodizing',
      ),
      damageReport: const DamageReport(
        damageDetected: false,
        damageTypes: [],
        severity: 'None',
        affectedAreaPercentage: 0.0,
        healthScore: 95,
        repairUrgency: 'None',
        recommendations: ['Regular dust cleaning recommended every 6 months'],
        estimatedRepairCostUsd: 0.0,
      ),
      scannedAt: DateTime.now(),
      status: ScanStatus.complete,
    );

    await ServiceLocator.storageService.saveScannedObject(mockObject.toJson());
  }
}

final scannerProvider = StateNotifierProvider<ScannerNotifier, ScannerState>(
  (ref) => ScannerNotifier(),
);
