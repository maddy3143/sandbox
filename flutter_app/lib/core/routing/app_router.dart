import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/scanner/screens/scanner_screen.dart';
import '../../features/scanner/screens/scan_result_screen.dart';
import '../../features/digital_twin/screens/digital_twin_screen.dart';
import '../../features/exploded_view/screens/exploded_view_screen.dart';
import '../../features/measurements/screens/measurements_screen.dart';
import '../../features/xray_mode/screens/xray_mode_screen.dart';
import '../../features/ai_assistant/screens/ai_assistant_screen.dart';
import '../../features/repair_guide/screens/repair_guide_screen.dart';
import '../../features/diagnostics/screens/diagnostics_screen.dart';
import '../../features/marketplace/screens/marketplace_screen.dart';
import '../../features/collaboration/screens/collaboration_screen.dart';
import '../../features/gamification/screens/gamification_screen.dart';
import '../../features/calls/screens/call_history_screen.dart';
import '../../features/calls/screens/call_detail_screen.dart';
import '../../features/calls/screens/incoming_call_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../constants/route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.scanner,
    debugLogDiagnostics: false,
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.scanner,
            name: RouteNames.scanner,
            pageBuilder: (context, state) => _buildPage(
              state,
              const ScannerScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.scanResult,
            name: RouteNames.scanResult,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(state, ScanResultScreen(objectId: objectId));
            },
          ),
          GoRoute(
            path: RouteNames.digitalTwin,
            name: RouteNames.digitalTwin,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(
                state,
                DigitalTwinScreen(objectId: objectId),
              );
            },
          ),
          GoRoute(
            path: RouteNames.explodedView,
            name: RouteNames.explodedView,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(
                state,
                ExplodedViewScreen(objectId: objectId),
              );
            },
          ),
          GoRoute(
            path: RouteNames.measurements,
            name: RouteNames.measurements,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(
                state,
                MeasurementsScreen(objectId: objectId),
              );
            },
          ),
          GoRoute(
            path: RouteNames.xrayMode,
            name: RouteNames.xrayMode,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(state, XRayModeScreen(objectId: objectId));
            },
          ),
          GoRoute(
            path: RouteNames.aiAssistant,
            name: RouteNames.aiAssistant,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(
                state,
                AIAssistantScreen(objectId: objectId),
              );
            },
          ),
          GoRoute(
            path: RouteNames.repairGuide,
            name: RouteNames.repairGuide,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(
                state,
                RepairGuideScreen(objectId: objectId),
              );
            },
          ),
          GoRoute(
            path: RouteNames.diagnostics,
            name: RouteNames.diagnostics,
            pageBuilder: (context, state) {
              final objectId = state.pathParameters['objectId'] ?? '';
              return _buildPage(
                state,
                DiagnosticsScreen(objectId: objectId),
              );
            },
          ),
          GoRoute(
            path: RouteNames.marketplace,
            name: RouteNames.marketplace,
            pageBuilder: (context, state) =>
                _buildPage(state, const MarketplaceScreen()),
          ),
          GoRoute(
            path: RouteNames.collaboration,
            name: RouteNames.collaboration,
            pageBuilder: (context, state) =>
                _buildPage(state, const CollaborationScreen()),
          ),
          GoRoute(
            path: RouteNames.gamification,
            name: RouteNames.gamification,
            pageBuilder: (context, state) =>
                _buildPage(state, const GamificationScreen()),
          ),
          GoRoute(
            path: RouteNames.callHistory,
            name: RouteNames.callHistory,
            pageBuilder: (context, state) =>
                _buildPage(state, const CallHistoryScreen()),
          ),
          // NOTE: incomingCall (/calls/incoming) must be declared before
          // callDetail (/calls/:callId) so go_router does not treat
          // the literal "incoming" segment as a callId parameter.
          GoRoute(
            path: RouteNames.incomingCall,
            name: RouteNames.incomingCall,
            pageBuilder: (context, state) {
              final callId =
                  state.uri.queryParameters['callId'] ?? '';
              final fromNumber =
                  state.uri.queryParameters['fromNumber'] ?? '';
              final callerName =
                  state.uri.queryParameters['callerName'];
              return _buildPage(
                state,
                IncomingCallScreen(
                  callId: callId,
                  fromNumber: fromNumber,
                  callerName: callerName,
                ),
              );
            },
          ),
          GoRoute(
            path: RouteNames.callDetail,
            name: RouteNames.callDetail,
            pageBuilder: (context, state) {
              final callId = state.pathParameters['callId'] ?? '';
              return _buildPage(state, CallDetailScreen(callId: callId));
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
});

CustomTransitionPage<void> _buildPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
  );
}
