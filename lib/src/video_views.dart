// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Keeps a `<video>` element in the document while the platform views that
/// show it come and go.
///
/// A playing video the browser sees leave the document is paused by it, even
/// when it comes back a frame later, and some browsers close its
/// Picture-in-Picture window as well. On the other platforms a player keeps
/// playing with no widget on screen, so here every view gets a container of
/// its own and the video only ever moves between attached containers:
///
/// * a new view takes the video once the engine attaches its container — a
///   frame after the view is created, so moving in right away would detach
///   a playing video for that frame;
/// * a view that leaves the screen hands the video to the newest other view
///   still attached, or to a hidden container of its own.
class VideoViews {
  /// Creates the views of [videoElement].
  VideoViews(this._videoElement);

  /// Frames to wait for the engine to attach a new container; a view that is
  /// not attached by then was never shown.
  static const int _maxAttachFrames = 300;

  final web.HTMLVideoElement _videoElement;

  /// The containers by view id.
  final Map<int, web.HTMLElement> _containers = <int, web.HTMLElement>{};

  /// Ids of the views on screen, oldest first.
  final List<int> _shownViewIds = <int>[];

  /// Holds the video while no view shows it; created on first use.
  web.HTMLElement? _hiddenContainer;

  bool _isDisposed = false;

  /// Creates the container of the view [viewId], for the platform view
  /// factory.
  web.HTMLElement create(int viewId) {
    final web.HTMLElement container = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%';
    _containers[viewId] = container;
    _shownViewIds.add(viewId);
    _takeVideo(viewId);
    return container;
  }

  /// The view [viewId] is back on screen after [hide], when its widget moves
  /// within the tree.
  void show(int viewId) {
    if (!_containers.containsKey(viewId)) {
      return;
    }
    _shownViewIds
      ..remove(viewId)
      ..add(viewId);
    _takeVideo(viewId);
  }

  /// The view [viewId] leaves the screen, and its container is about to leave
  /// the document.
  void hide(int viewId) {
    _shownViewIds.remove(viewId);
    final web.HTMLElement? container = _containers[viewId];
    if (container == null || _videoElement.parentNode != container) {
      return;
    }
    // Out of the document already: nothing to keep playing.
    if (!_videoElement.isConnected) {
      return;
    }
    _moveVideo(_newestAttachedContainer ?? _hidden);
  }

  /// The view [viewId] is gone.
  void dispose(int viewId) {
    hide(viewId);
    _containers.remove(viewId);
  }

  /// Takes the video out of the document, for good.
  void disposeAll() {
    _isDisposed = true;
    _containers.clear();
    _shownViewIds.clear();
    _videoElement.remove();
    _hiddenContainer?.remove();
    _hiddenContainer = null;
  }

  web.HTMLElement? get _newestAttachedContainer {
    for (final int viewId in _shownViewIds.reversed) {
      final web.HTMLElement? container = _containers[viewId];
      if (container != null && container.isConnected) {
        return container;
      }
    }
    return null;
  }

  web.HTMLElement get _hidden {
    final web.HTMLElement? existing = _hiddenContainer;
    if (existing != null) {
      return existing;
    }
    final web.HTMLElement container = web.HTMLDivElement()
      ..style.display = 'none'
      ..setAttribute('aria-hidden', 'true');
    web.document.body!.append(container);
    return _hiddenContainer = container;
  }

  /// A video out of the document moves in at once: it has nothing to lose.
  void _takeVideo(int viewId) {
    final web.HTMLElement container = _containers[viewId]!;
    if (!_videoElement.isConnected) {
      container.append(_videoElement);
      return;
    }
    _takeVideoWhenAttached(viewId, frame: 0);
  }

  /// Polls once a frame: the engine reports nothing when it attaches a
  /// container. Gives up when a newer view takes over, the view leaves the
  /// screen, or it is never attached.
  void _takeVideoWhenAttached(int viewId, {required int frame}) {
    if (_isDisposed ||
        _shownViewIds.isEmpty ||
        _shownViewIds.last != viewId) {
      return;
    }
    final web.HTMLElement container = _containers[viewId]!;
    if (container.isConnected) {
      if (_videoElement.parentNode != container) {
        _moveVideo(container);
      }
      return;
    }
    if (frame >= _maxAttachFrames) {
      return;
    }
    web.window.requestAnimationFrame(
      ((double _) => _takeVideoWhenAttached(viewId, frame: frame + 1)).toJS,
    );
  }

  /// `moveBefore` is the move made to keep the element's state where the
  /// browser has it; a plain append keeps the playback too as long as both
  /// containers are attached.
  void _moveVideo(web.HTMLElement target) {
    if (target.has('moveBefore')) {
      try {
        target.callMethod<JSAny?>('moveBefore'.toJS, _videoElement, null);
        return;
      } catch (_) {
        // Falls back to the append below.
      }
    }
    target.append(_videoElement);
  }
}
