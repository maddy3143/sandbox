import ARKit
import RealityKit
import Flutter

/**
 * Native ARKit bridge for the AR Object Scanner app.
 * Mirrors the Android ARCore bridge, exposing the same MethodChannel API.
 */
@objc class ArBridgePlugin: NSObject, FlutterPlugin {

    private var arView: ARView?
    private var anchors: [ARAnchor] = []
    private var channel: FlutterMethodChannel?
    private var arSession: ARSession?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "ar_object_scanner/ar_service",
            binaryMessenger: registrar.messenger()
        )
        let instance = ArBridgePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(result: result)
        case "startPlaneDetection":
            handleStartPlaneDetection(result: result)
        case "stopPlaneDetection":
            handleStopPlaneDetection(result: result)
        case "createSession":
            guard let args = call.arguments as? [String: Any],
                  let objectId = args["objectId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing objectId", details: nil))
                return
            }
            handleCreateSession(objectId: objectId, result: result)
        case "placeObject":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
                return
            }
            handlePlaceObject(args: args, result: result)
        case "showOverlay":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing args", details: nil))
                return
            }
            handleShowOverlay(args: args, result: result)
        case "highlightComponent":
            guard let args = call.arguments as? [String: Any],
                  let componentId = args["componentId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing componentId", details: nil))
                return
            }
            handleHighlightComponent(componentId: componentId, result: result)
        case "measureDistance":
            guard let args = call.arguments as? [String: Any],
                  let pointA = args["pointA"] as? [Double],
                  let pointB = args["pointB"] as? [Double] else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing points", details: nil))
                return
            }
            handleMeasureDistance(pointA: pointA, pointB: pointB, result: result)
        case "clearScene":
            handleClearScene(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(result: @escaping FlutterResult) {
        guard ARWorldTrackingConfiguration.isSupported else {
            result(false)
            return
        }
        arSession = ARSession()
        result(true)
    }

    private func handleStartPlaneDetection(result: @escaping FlutterResult) {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arSession?.run(config)
        result(nil)
    }

    private func handleStopPlaneDetection(result: @escaping FlutterResult) {
        arSession?.pause()
        result(nil)
    }

    private func handleCreateSession(objectId: String, result: @escaping FlutterResult) {
        let sessionId = "ar_\(objectId)_\(Int(Date().timeIntervalSince1970 * 1000))"
        result(sessionId)
    }

    private func handlePlaceObject(args: [String: Any], result: @escaping FlutterResult) {
        // In production: load USDZ model via Reality Composer and place at hit-test position
        let anchorId = "anc_\(Int(Date().timeIntervalSince1970 * 1000))"
        result(["anchor_id": anchorId, "status": "placed"])
    }

    private func handleShowOverlay(args: [String: Any], result: @escaping FlutterResult) {
        let label = args["label"] as? String ?? ""
        let overlayId = "ovl_\(Int(Date().timeIntervalSince1970 * 1000))"
        result(["overlay_id": overlayId, "label": label])
    }

    private func handleHighlightComponent(componentId: String, result: @escaping FlutterResult) {
        result(["component_id": componentId, "highlighted": true])
    }

    private func handleMeasureDistance(pointA: [Double], pointB: [Double], result: @escaping FlutterResult) {
        let dx = pointB[0] - pointA[0]
        let dy = pointB[1] - pointA[1]
        let dz = pointB[2] - pointA[2]
        let distanceM = sqrt(dx * dx + dy * dy + dz * dz)
        result([
            "distance_m": distanceM,
            "distance_cm": distanceM * 100,
            "distance_inches": distanceM * 39.37,
        ])
    }

    private func handleClearScene(result: @escaping FlutterResult) {
        anchors.removeAll()
        result(nil)
    }
}
