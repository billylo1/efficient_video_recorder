package org.evergreenlabs.efficient_video_recorder

import android.app.Activity
import android.content.ComponentCallbacks2
import android.content.res.Configuration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EfficientVideoRecorderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    private var activity: Activity? = null
    private var controller: CameraXRecorderController? = null

    private val componentCallbacks = object : ComponentCallbacks2 {
        override fun onConfigurationChanged(newConfig: Configuration) {
            controller?.setTargetRotation(null)
        }
        @Suppress("DEPRECATION")
        override fun onLowMemory() {}
        override fun onTrimMemory(level: Int) {}
    }

    companion object {
        const val METHOD_CHANNEL = "org.evergreenlabs.efficient_video_recorder/methods"
        const val EVENT_CHANNEL = "org.evergreenlabs.efficient_video_recorder/events"
        const val VIEW_TYPE = "org.evergreenlabs.efficient_video_recorder/preview"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)

        binding.platformViewRegistry.registerViewFactory(
            VIEW_TYPE,
            RecorderPreviewViewFactory { controller }
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        controller?.dispose()
        controller = null
        flutterPluginBinding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        controller = CameraXRecorderController(binding.activity)
        binding.activity.registerComponentCallbacks(componentCallbacks)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity?.unregisterComponentCallbacks(componentCallbacks)
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.activity.registerComponentCallbacks(componentCallbacks)
        controller?.setTargetRotation(null)
    }

    override fun onDetachedFromActivity() {
        activity?.unregisterComponentCallbacks(componentCallbacks)
        controller?.dispose()
        controller = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val ctrl = controller
        if (ctrl == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to an active Android Activity", null)
            return
        }

        when (call.method) {
            "initialize" -> {
                val quality = call.argument<String>("quality") ?: "sd"
                val facing = call.argument<String>("facing") ?: "back"
                val fps = call.argument<Int>("fps") ?: 24
                val disableStabilization = call.argument<Boolean>("disableStabilization") ?: true
                ctrl.initialize(quality, facing, fps, disableStabilization, result)
            }
            "startRecording" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "Path is required to start recording", null)
                } else {
                    ctrl.startRecording(path, result)
                }
            }
            "stopRecording" -> {
                ctrl.stopRecording(result)
            }
            "setQuality" -> {
                val quality = call.argument<String>("quality") ?: "sd"
                ctrl.setQuality(quality, result)
            }
            "setTargetRotation" -> {
                val rotation = call.argument<Int>("rotation")
                ctrl.setTargetRotation(rotation)
                result.success(true)
            }
            "pause" -> {
                ctrl.pause()
                result.success(true)
            }
            "resume" -> {
                ctrl.resume()
                result.success(true)
            }
            "isRecording" -> {
                result.success(ctrl.isRecording())
            }
            "isInitialized" -> {
                result.success(ctrl.isInitialized())
            }
            "dispose" -> {
                ctrl.dispose()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        controller?.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        controller?.setEventSink(null)
    }
}
