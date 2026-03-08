import 'dart:js_interop';

/// Whether the CanvasKit renderer is being used on web.
///
/// Always returns `false` on non-web.
///
/// See https://stackoverflow.com/a/66777112/6509751 for reference.
@JS('window.flutterCanvasKit')
external JSAny? get _windowFlutterCanvasKit;

bool get isCanvasKit => _windowFlutterCanvasKit != null;
