import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:efficient_video_recorder/efficient_video_recorder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('controller instantiate and options test', (WidgetTester tester) async {
    final controller = EfficientVideoRecorderController();
    expect(controller.isInitialized, isFalse);
    expect(controller.isRecording, isFalse);
    expect(controller.options.quality, VideoQuality.sd);
    expect(controller.options.targetFps, 24);
  });
}
