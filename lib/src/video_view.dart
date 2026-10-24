// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'video_views.dart';

/// The platform view of a player that keeps its video playing when the view
/// leaves the screen, see [VideoViews].
class VideoView extends StatefulWidget {
  /// Shows the platform view [viewType]; [views] is `null` for a player that
  /// is already disposed.
  const VideoView({
    required this.viewType,
    required this.views,
    super.key,
  });

  /// The platform view type of the player.
  final String viewType;

  /// The views of the player.
  final VideoViews? views;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  int? _viewId;

  void _onPlatformViewCreated(int viewId) {
    // The view came up after its widget had gone.
    if (!mounted) {
      widget.views?.dispose(viewId);
      return;
    }
    _viewId = viewId;
  }

  @override
  void activate() {
    super.activate();
    final int? viewId = _viewId;
    if (viewId != null) {
      widget.views?.show(viewId);
    }
  }

  // Runs before the platform view below is disposed, while its container is
  // still in the document: the video moves out of it in time.
  @override
  void deactivate() {
    final int? viewId = _viewId;
    if (viewId != null) {
      widget.views?.hide(viewId);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    final int? viewId = _viewId;
    if (viewId != null) {
      widget.views?.dispose(viewId);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: widget.viewType,
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
