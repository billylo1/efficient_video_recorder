# Efficient Video Recorder for Flutter

[![pub package](https://img.shields.io/pub/v/efficient_video_recorder.svg)](https://pub.dev/packages/efficient_video_recorder)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![platform](https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey.svg)](https://flutter.dev)

A high-efficiency, low-power camera video recorder plugin for Flutter. Purpose-built for **dashcams, action cams, driving companions, and background/continuous recording** where device thermals, battery life, and smooth UI frame rates matter.

---

## ⚡ The Problem with the Official `camera` Plugin

The official Flutter `camera` plugin (`camera_android_camerax`) was engineered as a general-purpose camera solution for taking photos, analyzing barcodes/ML, and streaming frames. On Android, this design introduces significant overhead during continuous video recording:

1. **Dual/Triple CameraX Use Cases**: The standard plugin often binds 3 to 4 use cases simultaneously (`Preview + ImageCapture + VideoCapture + ImageAnalysis`). On most Android devices, exceeding concurrent hardware HAL streams forces CameraX into an **OpenGL `StreamSharing` software-fallback pipeline**, doubling GPU & memory bus consumption.
2. **Flutter Texture Copy Loop**: Preview frames are converted into Flutter GPU textures via `SurfaceProducer`. Impeller/Skia must redraw every camera frame at 30–60 fps directly inside the Flutter rendering loop—competing with 3D vector maps, animations, and UI widgets.
3. **Thermal Accumulation & Battery Drain**: Uncapped 30/60 fps capture and active electronic image stabilization (EIS) cause phones to overheat within minutes, leading to aggressive OS thermal throttling.

---

## 🚀 The Solution: `efficient_video_recorder`

`efficient_video_recorder` takes a hardware-native, minimal-footprint approach:

| Capability | Official `camera` Plugin | `efficient_video_recorder` |
| :--- | :--- | :--- |
| **Active HAL Streams** | 3–4 (triggers OpenGL fallback) | **Strictly 2** (`Preview` + `VideoCapture`) |
| **Preview Rendering** | Flutter GPU Texture copy | **Zero-copy `SurfaceView`** (Hardware Overlay) |
| **Capture FPS** | Uncapped (30–60 fps) | **Capped to 24 fps** (saves ~20–30% ISP load) |
| **Bitrate Control** | Platform default (variable) | **Explicit Presets** (2.5 Mbps SD / 4.5 Mbps HD / 8 Mbps FHD) |
| **Video Stabilization** | Always enabled | **Disabled by default** (eliminates gyro sensor drain) |
| **Direct File Output** | Temporary cache + Dart copy | **Direct destination write** via MediaCodec |
| **Gesture Handling** | Requires manual overlay tuning | **Automatic pass-through** (`IgnorePointer` & transparent hit-test) |

### 📊 Real Device Benchmarks (Pixel 10a, Android 17)

Testing continuous recording side-by-side with a 3D Google Navigation map:

- **`cameraserver` CPU**: Dropped from **~35–45%** down to **~9.0%**.
- **Frame Render Latency**: 50th percentile: **5 ms**, 95th percentile: **8 ms**.
- **Janky Frames**: **1.69%** (zero slow bitmap uploads).
- **Thermals**: Maintained comfortable ~40.5 °C skin temperature with **0 cooling/throttling events**.

---

## 📦 Getting Started

### 1. Add Dependency

Add `efficient_video_recorder` to your `pubspec.yaml`:

```yaml
dependencies:
  efficient_video_recorder: ^0.1.0
```

### 2. Configure Platform Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to record video.</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app requires microphone access for video audio.</string>
```

---

## 💻 Usage

### Basic Example

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:efficient_video_recorder/efficient_video_recorder.dart';

class DashcamWidget extends StatefulWidget {
  const DashcamWidget({super.key});

  @override
  State<DashcamWidget> createState() => _DashcamWidgetState();
}

class _DashcamWidgetState extends State<DashcamWidget> {
  final _controller = EfficientVideoRecorderController();

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _controller.initialize(
      options: const RecorderOptions(
        quality: VideoQuality.sd, // SD 480p @ 2.5 Mbps for battery savings
        facing: CameraFacing.back,
        targetFps: 24,            // 24 fps cuts ISP power consumption
        disableStabilization: true,
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecord() async {
    if (_controller.isRecording) {
      final File? savedFile = await _controller.stopRecording();
      print('Video saved to: ${savedFile?.path}');
    } else {
      await _controller.startRecording('/path/to/my_clip.mp4');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _toggleRecord,
      child: SizedBox(
        width: 160,
        height: 120,
        child: Stack(
          children: [
            EfficientVideoPreview(
              controller: _controller,
              borderRadius: BorderRadius.circular(12),
            ),
            if (_controller.isRecording)
              const Positioned(
                bottom: 8,
                right: 8,
                child: Icon(Icons.fiber_manual_record, color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
```

---

## ⚙️ Configuration & Quality Presets

```dart
enum VideoQuality {
  sd,   // 480p (2.5 Mbps) — Lowest heat and battery usage. Recommended for dashcam.
  hd,   // 720p (4.5 Mbps) — Balanced detail and efficiency.
  fhd,  // 1080p (8.0 Mbps) — High detail.
}
```

To switch video quality dynamically on the fly:
```dart
await controller.setQuality(VideoQuality.hd);
```

---

## 🛠️ Lifecycle Management

When your app moves to the background, pause the camera session to release hardware locks:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    _controller.pause();
  } else if (state == AppLifecycleState.resumed) {
    _controller.resume();
  }
}
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, pull requests, and benchmarks.

1. Fork the repo: `https://github.com/billylo1/efficient_video_recorder`
2. Create your feature branch: `git checkout -b feature/my-feature`
3. Verify analysis & tests:
   ```bash
   flutter analyze
   flutter test
   ```
4. Commit your changes: `git commit -am 'Add some feature'`
5. Push to the branch: `git push origin feature/my-feature`
6. Open a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
