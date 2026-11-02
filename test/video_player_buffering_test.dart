@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_web/hls_options.dart';
import 'package:video_player_web/src/video_player.dart';
import 'package:web/web.dart' as web;

/// The JS boundary behaves like hls.js, without any playlist or segment fetches.
/// This checks when options/events reach the player, rather than a config map.
void main() {
  late web.HTMLVideoElement video;
  late VideoPlayer player;
  late List<(double, double)> ranges;
  late List<VideoEvent> events;
  late StreamSubscription<VideoEvent> subscription;
  late web.HTMLScriptElement script;

  setUp(() {
    script = web.HTMLScriptElement()
      ..text = '''
globalThis.hlsCreations = 0;
globalThis.Hls = class {
  static DefaultConfig = {maxBufferLength:30, maxMaxBufferLength:600,
    backBufferLength:Infinity, frontBufferFlushThreshold:Infinity, maxBufferSize:60000000};
  constructor(config = {}) {
    if (config === null) throw new TypeError('hls.js does not accept null config');
    this.config = {...Hls.DefaultConfig, ...config};
    this.handlers = {}; this.loads = 0;
    globalThis.testHls = this; globalThis.hlsCreations++;
  }
  on(name, callback) { this.handlers[name] = callback; }
  attachMedia(media) { this.media = media; }
  loadSource(url) { this.loads++; this.initialConfig = {...this.config}; }
  emit(name) { this.handlers[name]?.(name, {}); }
  destroy() { this.handlers = {}; }
};
''';
    web.document.head!.append(script);
    video = web.HTMLVideoElement();
    ranges = [(0, 20)];
    _defineProperty(
        video,
        'buffered'.toJS,
        _PropertyDescriptor(
            get: (() {
          final JSObject result = JSObject();
          result.setProperty('length'.toJS, ranges.length.toJS);
          result.setProperty(
              'start'.toJS, ((int index) => ranges[index].$1).toJS);
          result.setProperty(
              'end'.toJS, ((int index) => ranges[index].$2).toJS);
          return result;
        }).toJS));
    player = VideoPlayer(videoElement: video, hlsLoader: () async => true);
    events = [];
    subscription = player.events.listen(events.add);
  });

  tearDown(() async {
    player.dispose();
    await subscription.cancel();
    script.remove();
  });

  test('progress updates paused buffering, including eviction, without polling',
      () async {
    player.initialize();
    expect(video.paused, isTrue);
    video.dispatchEvent(web.Event('progress'));
    await pumpEventQueue();
    ranges = [(0, 65)];
    video.dispatchEvent(web.Event('progress'));
    video.dispatchEvent(web.Event('progress'));
    await pumpEventQueue();
    ranges = [(10, 65)];
    video.dispatchEvent(web.Event('progress'));
    await pumpEventQueue();
    final updates = events
        .where((event) => event.eventType == VideoEventType.bufferingUpdate)
        .toList();
    expect(updates.map((event) => event.buffered!.single.end.inSeconds),
        [20, 65, 65]);
    expect(updates.last.buffered!.single.start.inSeconds, 10);
  });

  test('canplay ends waiting after a buffered seek', () async {
    player.initialize();
    video.dispatchEvent(web.Event('waiting'));
    video.dispatchEvent(web.Event('canplay'));
    await pumpEventQueue();
    expect(
        events
            .where((event) => event.eventType == VideoEventType.bufferingStart)
            .length,
        1);
    expect(
        events
            .where((event) => event.eventType == VideoEventType.bufferingEnd)
            .length,
        1);
  });

  test(
      'HLS ranges update while paused and an option change preserves the source',
      () async {
    await player.setOptions(const VideoPlayerWebHlsOptions(
      maxForwardBufferDuration: Duration(seconds: 120),
      backBufferDuration: Duration(seconds: 30),
    ));
    player.initialize(src: 'https://example.invalid/master.m3u8');
    await pumpEventQueue();
    final JSObject hls = web.window.getProperty<JSObject>('testHls'.toJS);
    final JSObject initial = hls.getProperty<JSObject>('initialConfig'.toJS);
    expect(
        initial.getProperty<JSNumber>('maxMaxBufferLength'.toJS).toDartDouble,
        120);
    expect(initial.getProperty<JSNumber>('backBufferLength'.toJS).toDartDouble,
        30);
    expect(
        initial
            .getProperty<JSNumber>('frontBufferFlushThreshold'.toJS)
            .toDartDouble,
        120);
    hls.callMethod<JSAny?>('emit'.toJS, 'hlsBufferAppended'.toJS);
    ranges = [(5, 80)];
    hls.callMethod<JSAny?>('emit'.toJS, 'hlsBufferFlushed'.toJS);
    await pumpEventQueue();
    expect(events.last.buffered!.single.end, const Duration(seconds: 80));
    await player.setOptions(const VideoPlayerWebHlsOptions(
      maxForwardBufferDuration: Duration(seconds: 15),
      backBufferDuration: Duration.zero,
      maxBufferSizeBytes: 1000000,
    ));
    final JSObject config = hls.getProperty<JSObject>('config'.toJS);
    expect(
        config.getProperty<JSNumber>('maxBufferLength'.toJS).toDartDouble, 15);
    expect(config.getProperty<JSNumber>('maxMaxBufferLength'.toJS).toDartDouble,
        15);
    expect(
        config.getProperty<JSNumber>('maxBufferSize'.toJS).toDartInt, 1000000);
    expect(hls.getProperty<JSNumber>('loads'.toJS).toDartInt, 1);
    expect(web.window.getProperty<JSNumber>('hlsCreations'.toJS).toDartInt, 1);
    expect(video.buffered.end(0), 80);
  });

  test('omitting HLS options preserves the bundled library defaults', () async {
    player.initialize(src: 'https://example.invalid/master.m3u8');
    await pumpEventQueue();
    final JSObject hls = web.window.getProperty<JSObject>('testHls'.toJS);
    final JSObject config = hls.getProperty<JSObject>('initialConfig'.toJS);
    expect(config.getProperty<JSNumber>('maxMaxBufferLength'.toJS).toDartDouble, 600);
    expect(config.getProperty<JSNumber>('backBufferLength'.toJS).toDartDouble, double.infinity);
  });

  test('disposing removes buffer listeners', () async {
    player.initialize();
    player.dispose();
    video.dispatchEvent(web.Event('progress'));
    video.dispatchEvent(web.Event('waiting'));
    await pumpEventQueue();
    expect(events, isEmpty);
  });

  test('invalid policies are rejected before changing an active player',
      () async {
    await expectLater(
        player.setOptions(const VideoPlayerWebHlsOptions(
          maxForwardBufferDuration: Duration.zero,
        )),
        throwsArgumentError);
    await expectLater(
        player.setOptions(const VideoPlayerWebHlsOptions(
          backBufferDuration: Duration(seconds: -1),
        )),
        throwsArgumentError);
    await expectLater(
        player.setOptions(const VideoPlayerWebHlsOptions(
          maxBufferSizeBytes: 0,
        )),
        throwsArgumentError);
  });
}

/// Exposes a read-only TimeRanges getter without fetching a media resource.
@JS('Object.defineProperty')
external void _defineProperty(
    JSObject object, JSString property, _PropertyDescriptor descriptor);

///
extension type _PropertyDescriptor._(JSObject _) implements JSObject {
  external factory _PropertyDescriptor({required JSFunction get});
}
