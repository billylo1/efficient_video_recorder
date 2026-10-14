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
        // COMPATIBLE mode uses TextureView. Unlike SurfaceView, TextureView behaves like
        // a standard Android View, seamlessly handling dynamic resizing, display rotation,
        // animations, and parent clipping (ClipRRect) without dropping hardware buffers.
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }

    init {
        controllerProvider()?.attachSurfaceProvider(previewView.surfaceProvider)
    }

    override fun getView(): View {
        return previewView
    }

    override fun dispose() {
        controllerProvider()?.detachSurfaceProvider(previewView.surfaceProvider)
    }
}
