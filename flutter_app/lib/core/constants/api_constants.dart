class ApiConstants {
  static const String baseUrl = 'https://api.arobjectscanner.com/v1';
  static const String wsUrl = 'wss://api.arobjectscanner.com/ws';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';

  // Scanner
  static const String scanObject = '/scan/analyze';
  static const String scanHistory = '/scan/history';
  static const String getObjectById = '/objects/{id}';

  // Digital Twin
  static const String generateTwin = '/twin/generate';
  static const String getTwinModel = '/twin/{id}/model';
  static const String getTwinComponents = '/twin/{id}/components';

  // Exploded View
  static const String getExplodedView = '/twin/{id}/exploded';
  static const String getAssemblySteps = '/twin/{id}/assembly';

  // Measurements
  static const String getMeasurements = '/objects/{id}/measurements';
  static const String calibrateMeasurements = '/measurements/calibrate';

  // X-Ray / Internal
  static const String getInternalStructure = '/objects/{id}/internal';
  static const String getXRayModel = '/twin/{id}/xray';

  // AI Assistant
  static const String chat = '/assistant/chat';
  static const String voiceQuery = '/assistant/voice';
  static const String getComponentInfo = '/components/{id}/info';

  // Repair Guide
  static const String getRepairGuide = '/repair/{objectId}/guide';
  static const String getRepairStep = '/repair/{objectId}/step/{stepId}';
  static const String submitRepairFeedback = '/repair/feedback';

  // Diagnostics
  static const String analyzeDamage = '/diagnostics/damage';
  static const String getHealthScore = '/diagnostics/{objectId}/health';
  static const String predictFailure = '/diagnostics/{objectId}/predict';

  // Marketplace
  static const String searchParts = '/marketplace/search';
  static const String getCompatibleParts = '/marketplace/compatible/{objectId}';
  static const String getNearbyTechnicians = '/marketplace/technicians';

  // Collaboration
  static const String createSession = '/collaboration/session';
  static const String joinSession = '/collaboration/session/{sessionId}/join';

  // Gamification
  static const String getAchievements = '/gamification/achievements';
  static const String getUserStats = '/gamification/stats';
  static const String getChallenges = '/gamification/challenges';

  // Simulation
  static const String runSimulation = '/simulation/run';
  static const String getSimulationResult = '/simulation/{id}/result';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const int maxRetries = 3;
}
