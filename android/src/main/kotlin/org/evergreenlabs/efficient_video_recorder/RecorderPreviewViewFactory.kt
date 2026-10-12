package org.evergreenlabs.efficient_video_recorder

import android.content.Context
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec

class RecorderPreviewViewFactory(
    private val controllerProvider: () -> CameraXRecorderController?
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return RecorderPreviewPlatformView(context, controllerProvider)
    }
}

class RecorderPreviewPlatformView(
    context: Context,
    private val controllerProvider: () -> CameraXRecorderController?
) : PlatformView {

    private val previewView: PreviewView = PreviewView(context).apply {
        // PERFORMANCE mode uses SurfaceView for zero-copy hardware composer display,
        // bypassing Flutter's GPU texture copy loop.
        implementationMode = PreviewView.ImplementationMode.PERFORMANCE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }

    init {
        controllerProvider()?.attachSurfaceProvider(previewView.surfaceProvider)
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        controllerProvider()?.detachSurfaceProvider()
    }
}
