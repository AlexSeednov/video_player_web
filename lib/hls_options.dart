import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Optional buffering policy for sources played through hls.js.
/// Native browser playback (including Safari HLS) ignores these fields.
final class VideoPlayerWebHlsOptions extends VideoPlayerWebOptions {
  /// Durations are media time, independent of playback speed. A complete
  /// segment may cross a threshold; the byte target is not a total memory cap.
  const VideoPlayerWebHlsOptions({
    this.maxForwardBufferDuration = const Duration(minutes: 10),
    this.backBufferDuration,
    this.maxBufferSizeBytes = 60000000,
    super.controls,
    super.allowContextMenu,
    super.allowRemotePlayback,
    super.poster,
  });

  /// Maximum loading horizon ahead of the playhead.
  final Duration maxForwardBufferDuration;

  /// Played media to retain. Null keeps hls.js's unbounded back buffer.
  final Duration? backBufferDuration;

  /// Forward byte target. hls.js still tries to keep up to 30 seconds of media
  /// (or the shorter forward horizon), even if that requires more bytes.
  final int maxBufferSizeBytes;

  /// Reject invalid policies before loading or changing an active source.
  void validate() {
    if (maxForwardBufferDuration <= Duration.zero) {
      throw ArgumentError.value(maxForwardBufferDuration,
          'maxForwardBufferDuration', 'Must be positive');
    }
    if (backBufferDuration != null && backBufferDuration! < Duration.zero) {
      throw ArgumentError.value(
          backBufferDuration, 'backBufferDuration', 'Must not be negative');
    }
    if (maxBufferSizeBytes <= 0) {
      throw ArgumentError.value(
          maxBufferSizeBytes, 'maxBufferSizeBytes', 'Must be positive');
    }
  }
}

/// Carries web options into creation, before the first HLS fragment is loaded.
/// Other platform implementations continue to use [VideoCreationOptions].
final class VideoPlayerWebCreationOptions extends VideoCreationOptions {
  /// Creates a web player with its initial options already available.
  const VideoPlayerWebCreationOptions({
    required super.dataSource,
    required super.viewType,
    this.webOptions,
  });

  /// The initial native-control and HLS configuration.
  final VideoPlayerWebOptions? webOptions;
}
