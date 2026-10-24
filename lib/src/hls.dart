// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

// HLS playback for browsers that cannot play it natively (Firefox, Chromium
// before 142): the bundled hls.js feeds the video element through Media
// Source Extensions. Safari and current Chromium play HLS themselves and never
// download the script.

/// The MIME type of an HLS playlist.
const String _hlsMimeType = 'application/vnd.apple.mpegurl';

/// hls.js shipped with this package, served with the app's assets.
const String _hlsScriptAsset =
    'packages/video_player_web/assets/hls/hls.min.js';

/// The hls.js event fired on loading and decoding errors.
const String hlsErrorEvent = 'hlsError';

/// The hls.js error type of a failure the decoder can recover from.
const String hlsMediaErrorType = 'mediaError';

/// The hls.js error type of a failure to load a playlist or a segment.
const String hlsNetworkErrorType = 'networkError';

/// The part of the hls.js `Hls` class the plugin uses.
@JS('Hls')
extension type Hls._(JSObject _) implements JSObject {
  /// A player with the default configuration.
  external Hls();

  /// Whether the browser has the Media Source Extensions hls.js needs.
  external static bool isSupported();

  /// Binds the player to [media]; hls.js sets its `src` itself.
  external void attachMedia(web.HTMLMediaElement media);

  /// Starts loading the playlist at [url].
  external void loadSource(String url);

  /// Subscribes [listener] to [event].
  external void on(String event, JSFunction listener);

  /// Restarts the decoder after a media error.
  external void recoverMediaError();

  /// Stops loading and detaches from the media element.
  external void destroy();
}

/// The payload of [hlsErrorEvent].
extension type HlsErrorData._(JSObject _) implements JSObject {
  /// [hlsMediaErrorType], [hlsNetworkErrorType] or another hls.js type.
  external String get type;

  /// What exactly failed, for example `manifestLoadError`.
  external String get details;

  /// hls.js gave up: playback cannot continue without intervention.
  external bool get fatal;
}

/// Whether [src] is an HLS playlist that [element] cannot play by itself.
bool needsHlsLibrary(web.HTMLVideoElement element, String src) {
  final String? path = Uri.tryParse(src)?.path.toLowerCase();
  if (path == null || !path.endsWith('.m3u8')) {
    return false;
  }

  return element.canPlayType(_hlsMimeType).isEmpty;
}

/// The bundled script, loaded once for all players.
Future<bool>? _hlsScriptLoading;

/// Loads hls.js on first use. `false` when the script could not be loaded or
/// the browser lacks Media Source Extensions; a failed load is retried by the
/// next call.
Future<bool> loadHlsLibrary() async {
  final bool isLoaded = await (_hlsScriptLoading ??= _loadScript());
  if (!isLoaded) {
    _hlsScriptLoading = null;
    return false;
  }

  return Hls.isSupported();
}

/// Appends the script tag and waits for it to load or fail.
Future<bool> _loadScript() {
  final web.HTMLScriptElement script = web.HTMLScriptElement()
    ..src = ui_web.assetManager.getAssetUrl(_hlsScriptAsset)
    ..async = true;

  final Future<bool> result = Future.any(<Future<bool>>[
    script.onLoad.first.then((_) => true),
    script.onError.first.then((_) => false),
  ]);
  web.document.head!.append(script);

  return result;
}
