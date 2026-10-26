// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_web/src/hls.dart';
import 'package:web/web.dart' as web;

// Which engine plays a source. Runs in Chrome:
// `flutter test --platform chrome test/hls_test.dart`.
void main() {
  late web.HTMLVideoElement video;

  setUp(() => video = web.HTMLVideoElement());

  test('Chromium plays HLS through hls.js though it claims native support', () {
    expect(needsHlsLibrary(video, 'https://host/id/master.m3u8'), isTrue);
  });

  test('the playlist is recognized by its path, not by the query', () {
    expect(needsHlsLibrary(video, 'https://host/master.m3u8?token=1'), isTrue);
    expect(needsHlsLibrary(video, 'https://host/file.mp4?f=.m3u8'), isFalse);
  });

  test('a progressive file plays natively', () {
    expect(needsHlsLibrary(video, 'https://host/file.mp4'), isFalse);
  });
}
