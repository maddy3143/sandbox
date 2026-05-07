import 'package:equatable/equatable.dart';

enum ObjectCategory {
  electronics,
  mechanical,
  furniture,
  automotive,
  appliances,
  tools,
  industrial,
  toys,
  medical,
  unknown,
}

enum ScanStatus { scanning, analyzing, processing, complete, failed }

class ScannedObject extends Equatable {
  final String id;
  final String name;
  final String brand;
  final String model;
  final String estimatedYear;
  final ObjectCategory category;
  final String description;
  final String probableUseCase;
  final double confidenceScore;
  final String imagePath;
  final String? thumbnailUrl;
  final String? model3dUrl;
  final ObjectMeasurements measurements;
  final List<ObjectComponent> components;
  final MaterialAnalysis materialAnalysis;
  final DamageReport? damageReport;
  final DateTime scannedAt;
  final ScanStatus status;

  const ScannedObject({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.estimatedYear,
    required this.category,
    required this.description,
    required this.probableUseCase,
    required this.confidenceScore,
    required this.imagePath,
    this.thumbnailUrl,
    this.model3dUrl,
    required this.measurements,
    required this.components,
    required this.materialAnalysis,
    this.damageReport,
    required this.scannedAt,
    required this.status,
  });

  factory ScannedObject.fromJson(Map<String, dynamic> json) {
    return ScannedObject(
      id: json['id'] as String,
      name: json['name'] as String,
      brand: json['brand'] as String? ?? 'Unknown',
      model: json['model'] as String? ?? 'Unknown',
      estimatedYear: json['estimated_year'] as String? ?? 'Unknown',
      category: ObjectCategory.values.firstWhere(
        (c) => c.name == (json['category'] as String? ?? 'unknown'),
        orElse: () => ObjectCategory.unknown,
      ),
      description: json['description'] as String? ?? '',
      probableUseCase: json['probable_use_case'] as String? ?? '',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      imagePath: json['image_path'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      model3dUrl: json['model_3d_url'] as String?,
      measurements: ObjectMeasurements.fromJson(
        json['measurements'] as Map<String, dynamic>? ?? {},
      ),
      components: (json['components'] as List<dynamic>? ?? [])
          .map((c) => ObjectComponent.fromJson(c as Map<String, dynamic>))
          .toList(),
      materialAnalysis: MaterialAnalysis.fromJson(
        json['material_analysis'] as Map<String, dynamic>? ?? {},
      ),
      damageReport: json['damage_report'] != null
          ? DamageReport.fromJson(json['damage_report'] as Map<String, dynamic>)
          : null,
      scannedAt: DateTime.parse(json['scanned_at'] as String),
      status: ScanStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'complete'),
        orElse: () => ScanStatus.complete,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'model': model,
    'estimated_year': estimatedYear,
    'category': category.name,
    'description': description,
    'probable_use_case': probableUseCase,
    'confidence_score': confidenceScore,
    'image_path': imagePath,
    'thumbnail_url': thumbnailUrl,
    'model_3d_url': model3dUrl,
    'measurements': measurements.toJson(),
    'components': components.map((c) => c.toJson()).toList(),
    'material_analysis': materialAnalysis.toJson(),
    'damage_report': damageReport?.toJson(),
    'scanned_at': scannedAt.toIso8601String(),
    'status': status.name,
  };

  @override
  List<Object?> get props => [id, name, brand, model, status];
}

class ObjectMeasurements extends Equatable {
  final double heightCm;
  final double widthCm;
  final double depthCm;
  final double? diameterCm;
  final double weightKg;
  final double surfaceAreaCm2;
  final double volumeCm3;
  final double confidenceScore;

  const ObjectMeasurements({
    required this.heightCm,
    required this.widthCm,
    required this.depthCm,
    this.diameterCm,
    required this.weightKg,
    required this.surfaceAreaCm2,
    required this.volumeCm3,
    required this.confidenceScore,
  });

  factory ObjectMeasurements.fromJson(Map<String, dynamic> json) {
    return ObjectMeasurements(
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 0.0,
      widthCm: (json['width_cm'] as num?)?.toDouble() ?? 0.0,
      depthCm: (json['depth_cm'] as num?)?.toDouble() ?? 0.0,
      diameterCm: (json['diameter_cm'] as num?)?.toDouble(),
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      surfaceAreaCm2: (json['surface_area_cm2'] as num?)?.toDouble() ?? 0.0,
      volumeCm3: (json['volume_cm3'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'height_cm': heightCm,
    'width_cm': widthCm,
    'depth_cm': depthCm,
    'diameter_cm': diameterCm,
    'weight_kg': weightKg,
    'surface_area_cm2': surfaceAreaCm2,
    'volume_cm3': volumeCm3,
    'confidence_score': confidenceScore,
  };

  @override
  List<Object?> get props => [heightCm, widthCm, depthCm];
}

class ObjectComponent extends Equatable {
  final String id;
  final String name;
  final String description;
  final String function;
  final String material;
  final List<double> boundingBox;
  final bool isRemovable;
  final List<String> connectedTo;
  final String? repairNote;
  final String? imageUrl;

  const ObjectComponent({
    required this.id,
    required this.name,
    required this.description,
    required this.function,
    required this.material,
    required this.boundingBox,
    required this.isRemovable,
    required this.connectedTo,
    this.repairNote,
    this.imageUrl,
  });

  factory ObjectComponent.fromJson(Map<String, dynamic> json) {
    return ObjectComponent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      function: json['function'] as String? ?? '',
      material: json['material'] as String? ?? '',
      boundingBox: (json['bounding_box'] as List<dynamic>? ?? [])
          .map((v) => (v as num).toDouble())
          .toList(),
      isRemovable: json['is_removable'] as bool? ?? false,
      connectedTo: (json['connected_to'] as List<dynamic>? ?? [])
          .map((v) => v as String)
          .toList(),
      repairNote: json['repair_note'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'function': function,
    'material': material,
    'bounding_box': boundingBox,
    'is_removable': isRemovable,
    'connected_to': connectedTo,
    'repair_note': repairNote,
    'image_url': imageUrl,
  };

  @override
  List<Object?> get props => [id, name];
}

class MaterialAnalysis extends Equatable {
  final String primaryMaterial;
  final String? secondaryMaterial;
  final String surfaceFinish;
  final double estimatedWeightKg;
  final double durabilityScore;
  final String heatResistance;
  final String corrosionResistance;
  final String? manufacturingProcess;

  const MaterialAnalysis({
    required this.primaryMaterial,
    this.secondaryMaterial,
    required this.surfaceFinish,
    required this.estimatedWeightKg,
    required this.durabilityScore,
    required this.heatResistance,
    required this.corrosionResistance,
    this.manufacturingProcess,
  });

  factory MaterialAnalysis.fromJson(Map<String, dynamic> json) {
    return MaterialAnalysis(
      primaryMaterial: json['primary_material'] as String? ?? 'Unknown',
      secondaryMaterial: json['secondary_material'] as String?,
      surfaceFinish: json['surface_finish'] as String? ?? 'Unknown',
      estimatedWeightKg:
          (json['estimated_weight_kg'] as num?)?.toDouble() ?? 0.0,
      durabilityScore: (json['durability_score'] as num?)?.toDouble() ?? 0.0,
      heatResistance: json['heat_resistance'] as String? ?? 'Unknown',
      corrosionResistance: json['corrosion_resistance'] as String? ?? 'Unknown',
      manufacturingProcess: json['manufacturing_process'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'primary_material': primaryMaterial,
    'secondary_material': secondaryMaterial,
    'surface_finish': surfaceFinish,
    'estimated_weight_kg': estimatedWeightKg,
    'durability_score': durabilityScore,
    'heat_resistance': heatResistance,
    'corrosion_resistance': corrosionResistance,
    'manufacturing_process': manufacturingProcess,
  };

  @override
  List<Object?> get props => [primaryMaterial, surfaceFinish];
}

class DamageReport extends Equatable {
  final bool damageDetected;
  final List<String> damageTypes;
  final String severity;
  final double affectedAreaPercentage;
  final int healthScore;
  final String repairUrgency;
  final List<String> recommendations;
  final double estimatedRepairCostUsd;

  const DamageReport({
    required this.damageDetected,
    required this.damageTypes,
    required this.severity,
    required this.affectedAreaPercentage,
    required this.healthScore,
    required this.repairUrgency,
    required this.recommendations,
    required this.estimatedRepairCostUsd,
  });

  factory DamageReport.fromJson(Map<String, dynamic> json) {
    return DamageReport(
      damageDetected: json['damage_detected'] as bool? ?? false,
      damageTypes: (json['damage_types'] as List<dynamic>? ?? [])
          .map((v) => v as String)
          .toList(),
      severity: json['severity'] as String? ?? 'None',
      affectedAreaPercentage:
          (json['affected_area_percentage'] as num?)?.toDouble() ?? 0.0,
      healthScore: json['health_score'] as int? ?? 100,
      repairUrgency: json['repair_urgency'] as String? ?? 'None',
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .map((v) => v as String)
          .toList(),
      estimatedRepairCostUsd:
          (json['estimated_repair_cost_usd'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'damage_detected': damageDetected,
    'damage_types': damageTypes,
    'severity': severity,
    'affected_area_percentage': affectedAreaPercentage,
    'health_score': healthScore,
    'repair_urgency': repairUrgency,
    'recommendations': recommendations,
    'estimated_repair_cost_usd': estimatedRepairCostUsd,
  };

  @override
  List<Object?> get props => [healthScore, severity];
}
