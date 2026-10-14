import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'recorder_events.dart';
import 'recorder_options.dart';

/// High-efficiency video recorder controller built for low-power, low-heat
/// continuous recording (such as dashcam, action recording, or fitness companion).
///
/// On Android, this uses a specialized CameraX 1.5.x configuration that binds
/// strictly two use cases (`Preview` + `VideoCapture`), caps frame rates to 24 fps,
/// uses explicit bitrates, and renders preview through zero-copy `SurfaceView` overlays.
class EfficientVideoRecorderController extends ChangeNotifier {
  EfficientVideoRecorderController();

  static const MethodChannel _methodChannel =
      MethodChannel('org.evergreenlabs.efficient_video_recorder/methods');
  static const EventChannel _eventChannel =
      EventChannel('org.evergreenlabs.efficient_video_recorder/events');

  bool _isInitialized = false;
  bool _isRecording = false;
  RecorderOptions _options = const RecorderOptions();

  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<RecorderEvent> _eventsController =
      StreamController<RecorderEvent>.broadcast();

  /// Whether the camera session is successfully initialized and ready.
  bool get isInitialized => _isInitialized;

  /// Whether video is actively recording.
  bool get isRecording => _isRecording;

  /// The active configuration options.
  RecorderOptions get options => _options;

  /// Stream of recording lifecycle events (started, finalized, error).
  Stream<RecorderEvent> get events => _eventsController.stream;

  /// Initialize the camera recording session with [options].
  Future<void> initialize({
    RecorderOptions options = const RecorderOptions(),
  }) async {
    _options = options;
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (Object error) {
        _eventsController.add(RecorderErrorEvent(error: error.toString()));
      },
    );

    try {
      final success = await _methodChannel.invokeMethod<bool>(
        'initialize',
        options.toMap(),
      );
      _isInitialized = success ?? false;
      notifyListeners();
    } catch (e) {
      _isInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  void _handleNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final eventName = raw['event'] as String?;
    switch (eventName) {
      case 'started':
        _isRecording = true;
        notifyListeners();
        _eventsController.add(
          RecorderStartedEvent(path: raw['path'] as String? ?? ''),
        );
        break;
      case 'finalized':
        _isRecording = false;
        notifyListeners();
        _eventsController.add(
          RecorderFinalizedEvent(path: raw['path'] as String? ?? ''),
        );
        break;
      case 'error':
        _isRecording = false;
        notifyListeners();
        _eventsController.add(
          RecorderErrorEvent(error: raw['error'] as String? ?? 'Unknown error'),
        );
        break;
    }
  }

  /// Start recording video directly into [filePath].
  Future<void> startRecording(String filePath) async {
    if (!_isInitialized) {
      throw StateError('Cannot start recording: controller is not initialized');
    }
    try {
      await _methodChannel.invokeMethod<bool>('startRecording', {
        'path': filePath,
      });
      _isRecording = true;
      notifyListeners();
    } catch (e) {
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Convenience wrapper to start recording directly into a [File].
  Future<void> startRecordingToFile(File file) {
    return startRecording(file.path);
  }

  /// Stop the active recording and return the saved [File], or `null` if not recording.
  Future<File?> stopRecording() async {
    if (!_isRecording && !_isInitialized) return null;
    try {
      final path = await _methodChannel.invokeMethod<String?>('stopRecording');
      _isRecording = false;
      notifyListeners();
      if (path != null && path.isNotEmpty) {
        final f = File(path);
        if (await f.exists()) return f;
      }
      return null;
    } catch (e) {
      _isRecording = false;
      notifyListeners();
      return null;
    }
  }

  /// Dynamically update the video quality preset (`sd`, `hd`, `fhd`).
  Future<void> setQuality(VideoQuality quality) async {
    _options = RecorderOptions(
      quality: quality,
      facing: _options.facing,
      targetFps: _options.targetFps,
      disableStabilization: _options.disableStabilization,
    );
    try {
      await _methodChannel.invokeMethod<bool>('setQuality', {
        'quality': quality.value,
      });
      notifyListeners();
    } catch (_) {}
  }

  /// Inform the camera of orientation changes (0, 90, 180, 270), or omit/pass null
  /// to automatically detect from the active display.
  Future<void> setTargetRotation([int? rotation]) async {
    if (!_isInitialized) return;
    try {
      await _methodChannel.invokeMethod<bool>('setTargetRotation', {
        if (rotation != null && rotation >= 0) 'rotation': rotation,
      });
    } catch (_) {}
  }

  /// Pause camera session when the app transitions to the background.
  Future<void> pause() async {
    if (!_isInitialized) return;
    try {
      await _methodChannel.invokeMethod<bool>('pause');
      _isRecording = false;
      notifyListeners();
    } catch (_) {}
  }

  /// Resume camera session when returning to the foreground.
  Future<void> resume() async {
    try {
      await _methodChannel.invokeMethod<bool>('resume');
      _isInitialized = true;
      notifyListeners();
    } catch (_) {
      _isInitialized = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _eventsController.close();
    try {
      _methodChannel.invokeMethod<bool>('dispose');
    } catch (_) {}
    _isInitialized = false;
    _isRecording = false;
    super.dispose();
  }
}
