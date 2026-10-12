/// Target video recording quality profile.
enum VideoQuality {
  /// Standard definition (480p), ~2.5 Mbps.
  /// Highly recommended for continuous dashcam or background recording
  /// to minimize battery usage and prevent thermal accumulation.
  sd('sd'),

  /// High definition (720p), ~4.5 Mbps.
  /// Balanced resolution for general-purpose recording.
  hd('hd'),

  /// Full high definition (1080p), ~8.0 Mbps.
  /// Crisp detail for short captures.
  fhd('fhd');

  const VideoQuality(this.value);
  final String value;

  static VideoQuality fromString(String val) {
    switch (val.toLowerCase()) {
      case 'fhd':
        return VideoQuality.fhd;
      case 'hd':
        return VideoQuality.hd;
      default:
        return VideoQuality.sd;
    }
  }
}

/// Lens facing for the camera sensor.
enum CameraFacing {
  back('back'),
  front('front');

  const CameraFacing(this.value);
  final String value;
}

/// Configuration options for initializing the [EfficientVideoRecorderController].
class RecorderOptions {
  const RecorderOptions({
    this.quality = VideoQuality.sd,
    this.facing = CameraFacing.back,
    this.targetFps = 24,
    this.disableStabilization = true,
  });

  /// The recording video resolution and bitrate preset.
  final VideoQuality quality;

  /// Back or front camera lens.
  final CameraFacing facing;

  /// Target sensor and encoder frames-per-second (e.g. 24 fps).
  /// Lowering fps from 30/60 to 24 saves ~20-30% ISP processing power.
  final int targetFps;

  /// Disables software/EIS video stabilization.
  /// Stabilization requires continuous sensor gyro polling and frame warping,
  /// causing measurable battery and thermal drain on Android.
  final bool disableStabilization;

  Map<String, dynamic> toMap() {
    return {
      'quality': quality.value,
      'facing': facing.value,
      'fps': targetFps,
      'disableStabilization': disableStabilization,
    };
  }
}
