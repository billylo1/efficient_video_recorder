import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:efficient_video_recorder/efficient_video_recorder.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Efficient Video Recorder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RecorderDemoScreen(),
    );
  }
}

class RecorderDemoScreen extends StatefulWidget {
  const RecorderDemoScreen({super.key});

  @override
  State<RecorderDemoScreen> createState() => _RecorderDemoScreenState();
}

class _RecorderDemoScreenState extends State<RecorderDemoScreen> {
  final EfficientVideoRecorderController _controller =
      EfficientVideoRecorderController();

  VideoQuality _selectedQuality = VideoQuality.sd;
  CameraFacing _selectedFacing = CameraFacing.back;
  File? _lastRecordedFile;
  String? _statusMessage;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _initCamera();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initCamera() async {
    setState(() => _isInitializing = true);
    try {
      await _controller.initialize(
        options: RecorderOptions(
          quality: _selectedQuality,
          facing: _selectedFacing,
          targetFps: 24,
          disableStabilization: true,
        ),
      );
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Ready (24 fps, stabilization off)';
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Init error: $e';
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_controller.isRecording) {
      final file = await _controller.stopRecording();
      setState(() {
        _lastRecordedFile = file;
        _statusMessage = file != null
            ? 'Saved: ${file.path.split('/').last} (${(file.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB)'
            : 'Recording stopped';
      });
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await _controller.startRecording(path);
      setState(() {
        _statusMessage = 'Recording to $path...';
      });
    }
  }

  Future<void> _changeQuality(VideoQuality quality) async {
    if (_controller.isRecording) return;
    setState(() => _selectedQuality = quality);
    await _controller.setQuality(quality);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Efficient Video Recorder'),
        actions: [
          IconButton(
            tooltip: 'Switch Camera',
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _controller.isRecording
                ? null
                : () async {
                    _selectedFacing = _selectedFacing == CameraFacing.back
                        ? CameraFacing.front
                        : CameraFacing.back;
                    await _initCamera();
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _isInitializing
                            ? const Center(child: CircularProgressIndicator())
                            : EfficientVideoPreview(
                                controller: _controller,
                                placeholder: const Center(
                                  child: Text('Camera initializing...'),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (_controller.isRecording)
                    Positioned(
                      top: 28,
                      right: 28,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'REC 24fps',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Text(
                        'Quality:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<VideoQuality>(
                        segments: const [
                          ButtonSegment(
                            value: VideoQuality.sd,
                            label: Text('SD 480p'),
                          ),
                          ButtonSegment(
                            value: VideoQuality.hd,
                            label: Text('HD 720p'),
                          ),
                          ButtonSegment(
                            value: VideoQuality.fhd,
                            label: Text('FHD 1080p'),
                          ),
                        ],
                        selected: {_selectedQuality},
                        onSelectionChanged: (set) {
                          if (set.isNotEmpty) _changeQuality(set.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_lastRecordedFile != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Last clip: ${_lastRecordedFile!.path.split('/').last}',
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (_statusMessage != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: FloatingActionButton.extended(
                backgroundColor:
                    _controller.isRecording ? Colors.red : Colors.deepPurple,
                onPressed: _isInitializing ? null : _toggleRecording,
                icon: Icon(
                  _controller.isRecording
                      ? Icons.stop
                      : Icons.videocam_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  _controller.isRecording
                      ? 'Stop Recording'
                      : 'Start Recording',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
