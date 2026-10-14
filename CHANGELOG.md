## 0.1.1

* Fix camera preview freezing or stopping after device rotation or resizing:
  - Switched `PreviewView` to `ImplementationMode.COMPATIBLE` (`TextureView`) to prevent hardware surface drops on configuration changes.
  - Guarded `detachSurfaceProvider` against race conditions during view recreation.
  - Added automatic display rotation tracking via `ComponentCallbacks2` on Android.
  - Made `setTargetRotation` auto-detect current display rotation and seamlessly re-bind/refresh preview surfaces when orientation changes.

## 0.1.0

* Initial open source release of `efficient_video_recorder`.
* **Android**:
  - Purpose-built CameraX 1.5.x module binding strictly 2 streams: `Preview` and `VideoCapture<Recorder>`.
  - Zero-copy hardware preview via `SurfaceView` (`PreviewView.ImplementationMode.PERFORMANCE`), bypassing the Flutter GPU texture-render loop.
  - Capped 24 fps capture mode to cut sensor & ISP workload by 20–30%.
  - Explicit bitrate presets: SD 480p (2.5 Mbps), HD 720p (4.5 Mbps), FHD 1080p (8.0 Mbps).
  - Software video stabilization disabled by default to eliminate gyro sensor polling & warping power drain.
  - Event-driven finalize callbacks (`VideoRecordEvent.Finalize`).
* **iOS**:
  - AVFoundation capture pipeline using `AVCaptureSession` and `AVCaptureMovieFileOutput`.
  - Native preview layer integration.
* **Flutter**:
  - Modern, lightweight `EfficientVideoRecorderController` with lifecycle management.
  - `EfficientVideoPreview` widget with gesture transparency so parent tap gestures work out-of-the-box.
