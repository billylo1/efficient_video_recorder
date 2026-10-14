import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:efficient_video_recorder/efficient_video_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel =
      MethodChannel('org.evergreenlabs.efficient_video_recorder/methods');

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'initialize':
          return true;
        case 'startRecording':
          return true;
        case 'stopRecording':
          return '/tmp/test_clip.mp4';
        case 'setQuality':
          return true;
        case 'setTargetRotation':
          return true;
        case 'pause':
          return true;
        case 'resume':
          return true;
        case 'dispose':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('RecorderOptions', () {
    test('defaults to SD 480p, 24 fps, stabilization disabled', () {
      const options = RecorderOptions();
      expect(options.quality, VideoQuality.sd);
      expect(options.facing, CameraFacing.back);
      expect(options.targetFps, 24);
      expect(options.disableStabilization, isTrue);

      final map = options.toMap();
      expect(map['quality'], 'sd');
      expect(map['facing'], 'back');
      expect(map['fps'], 24);
      expect(map['disableStabilization'], isTrue);
    });

    test('parses quality from string correctly', () {
      expect(VideoQuality.fromString('sd'), VideoQuality.sd);
      expect(VideoQuality.fromString('hd'), VideoQuality.hd);
      expect(VideoQuality.fromString('fhd'), VideoQuality.fhd);
      expect(VideoQuality.fromString('unknown'), VideoQuality.sd);
    });
  });

  group('EfficientVideoRecorderController', () {
    test('initialize invokes native method with options', () async {
      final controller = EfficientVideoRecorderController();
      expect(controller.isInitialized, isFalse);
      expect(controller.isRecording, isFalse);

      await controller.initialize(
        options: const RecorderOptions(
          quality: VideoQuality.hd,
          facing: CameraFacing.front,
          targetFps: 24,
          disableStabilization: true,
        ),
      );

      expect(controller.isInitialized, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'initialize');
      expect(log.first.arguments, {
        'quality': 'hd',
        'facing': 'front',
        'fps': 24,
        'disableStabilization': true,
      });

      controller.dispose();
    });

    test('startRecording invokes native channel with target path', () async {
      final controller = EfficientVideoRecorderController();
      await controller.initialize();
      log.clear();

      await controller.startRecording('/tmp/out.mp4');

      expect(controller.isRecording, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, 'startRecording');
      expect(log.first.arguments, {'path': '/tmp/out.mp4'});

      controller.dispose();
    });

    test('stopRecording invokes native channel and clears recording flag', () async {
      final controller = EfficientVideoRecorderController();
      await controller.initialize();
      await controller.startRecording('/tmp/out.mp4');
      log.clear();

      final result = await controller.stopRecording();

      expect(controller.isRecording, isFalse);
      expect(log.any((call) => call.method == 'stopRecording'), isTrue);
      expect(result, isNull); // file does not exist on test host

      controller.dispose();
    });

    test('setQuality invokes native setQuality and updates options', () async {
      final controller = EfficientVideoRecorderController();
      await controller.initialize();
      log.clear();

      await controller.setQuality(VideoQuality.fhd);

      expect(controller.options.quality, VideoQuality.fhd);
      expect(log, hasLength(1));
      expect(log.first.method, 'setQuality');
      expect(log.first.arguments, {'quality': 'fhd'});

      controller.dispose();
    });

    test('pause and resume invoke native methods', () async {
      final controller = EfficientVideoRecorderController();
      await controller.initialize();
      log.clear();

      await controller.pause();
      expect(log.any((call) => call.method == 'pause'), isTrue);

      await controller.resume();
      expect(log.any((call) => call.method == 'resume'), isTrue);

      controller.dispose();
    });

    test('setTargetRotation invokes native method with optional rotation', () async {
      final controller = EfficientVideoRecorderController();
      await controller.initialize();
      log.clear();

      await controller.setTargetRotation(90);
      expect(log.length, 1);
      expect(log.first.method, 'setTargetRotation');
      expect(log.first.arguments, {'rotation': 90});

      log.clear();
      await controller.setTargetRotation();
      expect(log.length, 1);
      expect(log.first.method, 'setTargetRotation');
      expect(log.first.arguments, isEmpty);

      controller.dispose();
    });
  });

  group('EfficientVideoPreview', () {
    testWidgets('renders placeholder when uninitialized', (WidgetTester tester) async {
      final controller = EfficientVideoRecorderController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EfficientVideoPreview(
              controller: controller,
              placeholder: const Text('Camera offline'),
            ),
          ),
        ),
      );

      expect(find.text('Camera offline'), findsOneWidget);
    });
  });
}
