import 'dart:js_interop';

@JS('Audio')
extension type _DomAudio._(JSObject _) implements JSObject {
  external factory _DomAudio([String src]);
  external JSPromise<JSAny?> play();
}

/// Chrome only allows audio after a synchronous play() during a user gesture.
/// just_audio awaits the MP3 load first, so the gesture is already gone.
void primeWebAudio() {
  _DomAudio(
    'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAZGF0YQAAAAA=',
  ).play();
}
