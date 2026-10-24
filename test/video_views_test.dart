// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_web/src/video_views.dart';
import 'package:web/web.dart' as web;

// The engine attaches a platform view container a frame after it creates it;
// these tests attach the containers themselves. Runs in a browser:
// `flutter test --platform chrome test/video_views_test.dart`.
void main() {
  late web.HTMLVideoElement video;
  late VideoViews views;

  Future<void> nextFrame() {
    final Completer<void> completer = Completer<void>();
    web.window.requestAnimationFrame(((double _) => completer.complete()).toJS);
    return completer.future;
  }

  setUp(() {
    video = web.HTMLVideoElement();
    views = VideoViews(video);
  });

  tearDown(() => views.disposeAll());

  test('a video out of the document moves into a new view at once', () {
    final web.HTMLElement container = views.create(1);

    expect(video.parentNode, container);
  });

  test('a view that leaves keeps the video in the document', () {
    final web.HTMLElement container = views.create(1);
    web.document.body!.append(container);

    views.hide(1);
    container.remove();

    expect(video.isConnected, isTrue);
    expect((video.parentNode! as web.HTMLElement).style.display, 'none');
  });

  test('a new view takes an attached video once it is attached itself',
      () async {
    final web.HTMLElement first = views.create(1);
    web.document.body!.append(first);

    final web.HTMLElement second = views.create(2);
    await nextFrame();
    expect(video.parentNode, first);

    web.document.body!.append(second);
    await nextFrame();
    expect(video.parentNode, second);

    first.remove();
    second.remove();
  });

  test('a leaving view hands the video to the newest attached one', () async {
    final web.HTMLElement first = views.create(1);
    web.document.body!.append(first);
    final web.HTMLElement second = views.create(2);
    web.document.body!.append(second);
    await nextFrame();

    views.hide(2);

    expect(video.parentNode, first);

    first.remove();
    second.remove();
  });

  test('a view back on screen takes the video again', () async {
    final web.HTMLElement container = views.create(1);
    web.document.body!.append(container);
    views.hide(1);

    views.show(1);
    await nextFrame();

    expect(video.parentNode, container);

    container.remove();
  });

  test('disposing takes the video out of the document', () {
    final web.HTMLElement container = views.create(1);
    web.document.body!.append(container);
    views.hide(1);
    final web.Node hidden = video.parentNode!;

    views.disposeAll();

    expect(video.isConnected, isFalse);
    expect(hidden.isConnected, isFalse);

    container.remove();
  });
}
