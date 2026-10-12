package org.evergreenlabs.efficient_video_recorder

import android.app.Activity
import android.os.Build
import android.util.Range
import android.view.Surface
import androidx.camera.core.CameraInfo
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.FallbackStrategy
import androidx.camera.video.FileOutputOptions
import androidx.camera.video.Quality
import androidx.camera.video.QualitySelector
import androidx.camera.video.Recorder
import androidx.camera.video.Recording
import androidx.camera.video.VideoCapture
import androidx.camera.video.VideoRecordEvent
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.common.util.concurrent.ListenableFuture
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

class CameraXRecorderController(private val activity: Activity) {

    private var cameraProvider: ProcessCameraProvider? = null
    private var preview: Preview? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    private var activeRecording: Recording? = null
    private var pendingStopResult: MethodChannel.Result? = null

    private var surfaceProvider: Preview.SurfaceProvider? = null
    private var eventSink: EventChannel.EventSink? = null

    private var currentQuality: String = "sd"
    private var currentFacing: String = "back"
    private var targetFps: Int = 24
    private var disableStabilization: Boolean = true
    private var isInitialized = false
    private val isStopping = AtomicBoolean(false)

    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    fun isRecording(): Boolean = activeRecording != null

    fun isInitialized(): Boolean = isInitialized

    fun initialize(
        quality: String,
        facing: String,
        fps: Int,
        disableStab: Boolean,
        result: MethodChannel.Result
    ) {
        currentQuality = quality
        currentFacing = facing
        targetFps = fps
        disableStabilization = disableStab

        val context = activity.applicationContext
        val cameraProviderFuture: ListenableFuture<ProcessCameraProvider> =
            ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindUseCases()
                isInitialized = true
                result.success(true)
            } catch (t: Throwable) {
                isInitialized = false
                result.error("INIT_FAILED", t.message ?: "Failed to initialize CameraX", null)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    fun attachSurfaceProvider(provider: Preview.SurfaceProvider) {
        this.surfaceProvider = provider
        preview?.setSurfaceProvider(provider)
    }

    fun detachSurfaceProvider() {
        this.surfaceProvider = null
        preview?.setSurfaceProvider(null)
    }

    private fun bindUseCases() {
        val provider = cameraProvider ?: return
        val lifecycleOwner = activity as? LifecycleOwner ?: return

        provider.unbindAll()

        // 1. Camera Selector (Back vs Front)
        val cameraSelector = if (currentFacing == "front") {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }

        // 2. Hardware Preview UseCase
        val previewBuilder = Preview.Builder()
        previewBuilder.setTargetRotation(getSurfaceRotation())

        // Constrain preview FPS if requested to save power
        if (targetFps > 0) {
            val range = Range(targetFps, targetFps)
            val camera2Ext = androidx.camera.camera2.interop.Camera2Interop.Extender(previewBuilder)
            camera2Ext.setCaptureRequestOption(
                android.hardware.camera2.CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE,
                range
            )
        }

        preview = previewBuilder.build()
        surfaceProvider?.let { preview?.setSurfaceProvider(it) }

        // 3. Quality & Bitrate Profile
        val (selectedQuality, targetBitrate) = when (currentQuality.lowercase()) {
            "fhd" -> Pair(Quality.FHD, 8_000_000)
            "hd" -> Pair(Quality.HD, 4_500_000)
            else -> Pair(Quality.SD, 2_500_000)
        }

        val qualitySelector = QualitySelector.from(
            selectedQuality,
            FallbackStrategy.lowerQualityOrHigherThan(selectedQuality)
        )

        // 4. VideoCapture with direct MediaCodec Recorder
        val recorderBuilder = Recorder.Builder()
            .setQualitySelector(qualitySelector)
            .setTargetVideoEncodingBitRate(targetBitrate)
            .setExecutor(ContextCompat.getMainExecutor(activity.applicationContext))

        val recorder = recorderBuilder.build()

        val videoCaptureBuilder = VideoCapture.Builder(recorder)
            .setTargetRotation(getSurfaceRotation())

        if (disableStabilization) {
            videoCaptureBuilder.setVideoStabilizationEnabled(false)
        }

        videoCapture = videoCaptureBuilder.build()

        // Bind ONLY Preview and VideoCapture (strictly 2 HAL streams)
        provider.bindToLifecycle(
            lifecycleOwner,
            cameraSelector,
            preview,
            videoCapture
        )
    }

    fun startRecording(path: String, result: MethodChannel.Result) {
        val vc = videoCapture
        if (vc == null) {
            result.error("NOT_INITIALIZED", "Camera is not initialized", null)
            return
        }
        if (activeRecording != null) {
            result.error("ALREADY_RECORDING", "A recording is already in progress", null)
            return
        }

        val targetFile = File(path)
        targetFile.parentFile?.mkdirs()

        val outputOptions = FileOutputOptions.Builder(targetFile).build()

        try {
            val recording = vc.output
                .prepareRecording(activity.applicationContext, outputOptions)
                .start(ContextCompat.getMainExecutor(activity.applicationContext)) { event ->
                    handleVideoRecordEvent(event, targetFile)
                }

            activeRecording = recording
            result.success(true)
        } catch (t: Throwable) {
            result.error("RECORD_START_FAILED", t.message ?: "Failed to start recording", null)
        }
    }

    private fun handleVideoRecordEvent(event: VideoRecordEvent, targetFile: File) {
        when (event) {
            is VideoRecordEvent.Start -> {
                eventSink?.success(
                    mapOf(
                        "event" to "started",
                        "path" to targetFile.absolutePath
                    )
                )
            }
            is VideoRecordEvent.Finalize -> {
                val stopResult = pendingStopResult
                pendingStopResult = null
                activeRecording = null
                isStopping.set(false)

                if (event.hasError()) {
                    val errMsg = "Recording finalized with error code: ${event.error}"
                    eventSink?.success(
                        mapOf(
                            "event" to "error",
                            "error" to errMsg
                        )
                    )
                    stopResult?.error("RECORDING_ERROR", errMsg, null)
                } else {
                    eventSink?.success(
                        mapOf(
                            "event" to "finalized",
                            "path" to targetFile.absolutePath
                        )
                    )
                    stopResult?.success(targetFile.absolutePath)
                }
            }
            is VideoRecordEvent.Status -> {
                // Recording is healthy and progressing
            }
        }
    }

    fun stopRecording(result: MethodChannel.Result) {
        val recording = activeRecording
        if (recording == null) {
            result.success(null)
            return
        }

        if (isStopping.getAndSet(true)) {
            result.error("ALREADY_STOPPING", "Stop recording is already in progress", null)
            return
        }

        pendingStopResult = result
        try {
            recording.stop()
        } catch (t: Throwable) {
            isStopping.set(false)
            pendingStopResult = null
            result.error("STOP_FAILED", t.message ?: "Failed to stop recording", null)
        }
    }

    fun setQuality(quality: String, result: MethodChannel.Result) {
        if (currentQuality == quality) {
            result.success(true)
            return
        }
        currentQuality = quality
        if (isInitialized && activeRecording == null) {
            try {
                bindUseCases()
                result.success(true)
            } catch (t: Throwable) {
                result.error("QUALITY_FAILED", t.message ?: "Failed to apply quality", null)
            }
        } else {
            result.success(true)
        }
    }

    fun setTargetRotation(rotation: Int) {
        preview?.targetRotation = rotation
        videoCapture?.targetRotation = rotation
    }

    fun pause() {
        if (activeRecording != null) {
            try {
                activeRecording?.stop()
            } catch (_: Throwable) {}
            activeRecording = null
        }
        cameraProvider?.unbindAll()
        isInitialized = false
    }

    fun resume() {
        if (!isInitialized && cameraProvider != null) {
            bindUseCases()
            isInitialized = true
        }
    }

    fun dispose() {
        detachSurfaceProvider()
        pause()
        cameraProvider = null
        preview = null
        videoCapture = null
        pendingStopResult = null
        eventSink = null
    }

    private fun getSurfaceRotation(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            activity.windowManager.defaultDisplay.rotation
        }
    }
}
