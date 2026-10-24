## test

This package uses integration tests for testing.

`video_views_test.dart` checks how the `<video>` element moves between the
containers of its views; it needs a browser but no network:
`flutter test --platform chrome test/video_views_test.dart`.

See `example/README.md` for more info.
