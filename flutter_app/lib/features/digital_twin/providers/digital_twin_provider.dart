import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/service_locator.dart';

class DigitalTwinState {
  final bool isLoading;
  final String? modelUrl;
  final int componentCount;
  final int polyCount;
  final String renderQuality;
  final bool isAutoRotating;
  final bool isSimulating;
  final double zoom;
  final String? error;

  const DigitalTwinState({
    this.isLoading = true,
    this.modelUrl,
    this.componentCount = 0,
    this.polyCount = 0,
    this.renderQuality = 'HIGH',
    this.isAutoRotating = false,
    this.isSimulating = false,
    this.zoom = 1.0,
    this.error,
  });

  DigitalTwinState copyWith({
    bool? isLoading,
    String? modelUrl,
    int? componentCount,
    int? polyCount,
    String? renderQuality,
    bool? isAutoRotating,
    bool? isSimulating,
    double? zoom,
    String? error,
  }) {
    return DigitalTwinState(
      isLoading: isLoading ?? this.isLoading,
      modelUrl: modelUrl ?? this.modelUrl,
      componentCount: componentCount ?? this.componentCount,
      polyCount: polyCount ?? this.polyCount,
      renderQuality: renderQuality ?? this.renderQuality,
      isAutoRotating: isAutoRotating ?? this.isAutoRotating,
      isSimulating: isSimulating ?? this.isSimulating,
      zoom: zoom ?? this.zoom,
      error: error,
    );
  }
}

class DigitalTwinNotifier extends StateNotifier<DigitalTwinState> {
  final String objectId;

  DigitalTwinNotifier(this.objectId) : super(const DigitalTwinState());

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await ServiceLocator.apiService.generateDigitalTwin(objectId);

      state = state.copyWith(
        isLoading: false,
        modelUrl: result['model_url'] as String?,
        componentCount: result['component_count'] as int? ?? 5,
        polyCount: result['poly_count'] as int? ?? 48,
        renderQuality: 'HIGH',
      );
    } catch (_) {
      // Use demo data when server unavailable
      state = state.copyWith(
        isLoading: false,
        componentCount: 5,
        polyCount: 48,
        renderQuality: 'HIGH',
      );
    }
  }

  void zoom(double factor) {
    final newZoom = (state.zoom * factor).clamp(0.3, 5.0);
    state = state.copyWith(zoom: newZoom);
  }

  void autoRotate() {
    state = state.copyWith(isAutoRotating: !state.isAutoRotating);
  }

  void resetCamera() {
    state = state.copyWith(zoom: 1.0, isAutoRotating: false);
  }

  void startSimulation() {
    state = state.copyWith(isSimulating: !state.isSimulating);
  }

  void setViewMode(String mode) {
    // Update shader parameters based on view mode
  }
}

final digitalTwinProvider = StateNotifierProvider.family<
    DigitalTwinNotifier, DigitalTwinState, String>(
  (ref, objectId) => DigitalTwinNotifier(objectId),
);
