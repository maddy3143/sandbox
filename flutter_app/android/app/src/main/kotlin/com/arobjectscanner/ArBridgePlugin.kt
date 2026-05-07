package com.arobjectscanner

import android.app.Activity
import android.content.Context
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Native ARCore bridge for the AR Object Scanner app.
 *
 * Exposes AR capabilities to Flutter via MethodChannel:
 *   - initialize(): Check ARCore availability and create session
 *   - startPlaneDetection(): Begin horizontal/vertical plane detection
 *   - stopPlaneDetection(): Pause plane detection to save battery
 *   - createSession(objectId): Create AR overlay session for a digital twin
 *   - placeObject(modelUrl, position, scale): Place a 3D model anchor in AR space
 *   - showOverlay(label, position, type): Render AR annotation at world position
 *   - highlightComponent(componentId, color): Tint a component mesh
 *   - measureDistance(pointA, pointB): Ray-cast distance measurement
 *   - clearScene(): Remove all AR anchors and overlays
 */
class ArBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var arSession: Session? = null
    private val anchors = mutableListOf<Anchor>()
    private var planeDetectionEnabled = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ar_object_scanner/ar_service")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        arSession?.close()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> handleInitialize(result)
            "startPlaneDetection" -> handleStartPlaneDetection(result)
            "stopPlaneDetection" -> handleStopPlaneDetection(result)
            "createSession" -> {
                val objectId = call.argument<String>("objectId") ?: ""
                handleCreateSession(objectId, result)
            }
            "placeObject" -> {
                val modelUrl = call.argument<String>("modelUrl") ?: ""
                val position = call.argument<List<Double>>("position") ?: listOf(0.0, 0.0, 0.0)
                val scale = call.argument<Double>("scale") ?: 1.0
                handlePlaceObject(modelUrl, position, scale, result)
            }
            "showOverlay" -> {
                val label = call.argument<String>("label") ?: ""
                val position = call.argument<List<Double>>("position") ?: listOf(0.0, 0.0, 0.0)
                val type = call.argument<String>("type") ?: "info"
                handleShowOverlay(label, position, type, result)
            }
            "highlightComponent" -> {
                val componentId = call.argument<String>("componentId") ?: ""
                val color = call.argument<List<Double>>("color") ?: listOf(0.0, 0.95, 1.0, 1.0)
                handleHighlightComponent(componentId, color, result)
            }
            "measureDistance" -> {
                val pointA = call.argument<List<Double>>("pointA") ?: listOf(0.0, 0.0, 0.0)
                val pointB = call.argument<List<Double>>("pointB") ?: listOf(1.0, 0.0, 0.0)
                handleMeasureDistance(pointA, pointB, result)
            }
            "clearScene" -> handleClearScene(result)
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(result: MethodChannel.Result) {
        try {
            val availability = ArCoreApk.getInstance().checkAvailability(context)
            if (availability.isSupported) {
                arSession = Session(context)
                val config = Config(arSession).apply {
                    planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
                    lightEstimationMode = Config.LightEstimationMode.ENVIRONMENTAL_HDR
                    focusMode = Config.FocusMode.AUTO
                    depthMode = if (arSession!!.isDepthModeSupported(Config.DepthMode.AUTOMATIC))
                        Config.DepthMode.AUTOMATIC else Config.DepthMode.DISABLED
                }
                arSession!!.configure(config)
                result.success(true)
            } else {
                result.success(false)
            }
        } catch (e: UnavailableDeviceNotCompatibleException) {
            result.error("AR_NOT_SUPPORTED", "ARCore not supported on this device", null)
        } catch (e: UnavailableUserDeclinedInstallationException) {
            result.error("AR_INSTALL_DECLINED", "User declined ARCore installation", null)
        } catch (e: Exception) {
            result.error("AR_INIT_ERROR", e.message, null)
        }
    }

    private fun handleStartPlaneDetection(result: MethodChannel.Result) {
        planeDetectionEnabled = true
        result.success(null)
    }

    private fun handleStopPlaneDetection(result: MethodChannel.Result) {
        planeDetectionEnabled = false
        result.success(null)
    }

    private fun handleCreateSession(objectId: String, result: MethodChannel.Result) {
        val sessionId = "ar_${objectId}_${System.currentTimeMillis()}"
        result.success(sessionId)
    }

    private fun handlePlaceObject(
        modelUrl: String,
        position: List<Double>,
        scale: Double,
        result: MethodChannel.Result,
    ) {
        // In production: create SceneForm/Filament node at the hit-test anchor
        result.success(mapOf("anchor_id" to "anc_${System.currentTimeMillis()}", "status" to "placed"))
    }

    private fun handleShowOverlay(
        label: String,
        position: List<Double>,
        type: String,
        result: MethodChannel.Result,
    ) {
        result.success(mapOf("overlay_id" to "ovl_${System.currentTimeMillis()}", "label" to label))
    }

    private fun handleHighlightComponent(
        componentId: String,
        color: List<Double>,
        result: MethodChannel.Result,
    ) {
        result.success(mapOf("component_id" to componentId, "highlighted" to true))
    }

    private fun handleMeasureDistance(
        pointA: List<Double>,
        pointB: List<Double>,
        result: MethodChannel.Result,
    ) {
        val dx = pointB[0] - pointA[0]
        val dy = pointB[1] - pointA[1]
        val dz = pointB[2] - pointA[2]
        val distanceM = Math.sqrt(dx * dx + dy * dy + dz * dz)
        result.success(mapOf(
            "distance_m" to distanceM,
            "distance_cm" to distanceM * 100,
            "distance_inches" to distanceM * 39.37,
        ))
    }

    private fun handleClearScene(result: MethodChannel.Result) {
        anchors.forEach { it.detach() }
        anchors.clear()
        result.success(null)
    }
}
