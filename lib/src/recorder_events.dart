/// Base class for events emitted by [EfficientVideoRecorderController.events].
sealed class RecorderEvent {
  const RecorderEvent();
}

/// Emitted when video recording has started on the native hardware encoder.
class RecorderStartedEvent extends RecorderEvent {
  const RecorderStartedEvent({required this.path});
  final String path;

  @override
  String toString() => 'RecorderStartedEvent(path: $path)';
}

/// Emitted when video recording has finished and finalized to disk.
class RecorderFinalizedEvent extends RecorderEvent {
  const RecorderFinalizedEvent({required this.path});
  final String path;

  @override
  String toString() => 'RecorderFinalizedEvent(path: $path)';
}

/// Emitted when an error occurred during recording.
class RecorderErrorEvent extends RecorderEvent {
  const RecorderErrorEvent({required this.error});
  final String error;

  @override
  String toString() => 'RecorderErrorEvent(error: $error)';
}
