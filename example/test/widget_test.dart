import 'package:flutter_test/flutter_test.dart';
import 'package:efficient_video_recorder_example/main.dart';

void main() {
  testWidgets('Renders ExampleApp and title', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Efficient Video Recorder'), findsOneWidget);
  });
}
