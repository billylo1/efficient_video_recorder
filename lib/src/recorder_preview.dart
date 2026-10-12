import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'recorder_controller.dart';

/// Embedded camera preview widget connected to [EfficientVideoRecorderController].
///
/// On Android, this uses a high-performance `SurfaceView` platform view to bypass
/// the Flutter GPU texture copy loop, eliminating rendering overhead on 3D maps or heavy UI.
///
/// Touches are transparently forwarded so enclosing Flutter gestures (like tap-to-record)
/// work seamlessly.
class EfficientVideoPreview extends StatelessWidget {
  const EfficientVideoPreview({
    super.key,
    required this.controller,
    this.borderRadius,
    this.placeholder,
    this.fit = BoxFit.cover,
  });

  /// The active recorder controller.
  final EfficientVideoRecorderController controller;

  /// Optional corner radius clipping.
  final BorderRadius? borderRadius;

  /// Optional widget shown when the controller is uninitialized.
  final Widget? placeholder;

  /// Scaling behavior for the preview container.
  final BoxFit fit;

  static const String viewType =
      'org.evergreenlabs.efficient_video_recorder/preview';

  @override
  Widget build(BuildContext context) {
    if (!controller.isInitialized) {
      return placeholder ?? const ColoredBox(color: Colors.black);
    }

    Widget nativeView;
    if (defaultTargetPlatform == TargetPlatform.android) {
      nativeView = PlatformViewLink(
        viewType: viewType,
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        ),
        onCreatePlatformView: (params) =>
            PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: params.viewType,
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
        )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      nativeView = const UiKitView(
        viewType: viewType,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      );
    } else {
      nativeView = placeholder ?? const ColoredBox(color: Colors.black);
    }

    // IgnorePointer ensures native Android SurfaceView doesn't absorb parent Flutter gestures
    final view = IgnorePointer(child: nativeView);

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: view,
      );
    }
    return view;
  }
}
