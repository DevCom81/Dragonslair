import 'dart:js_interop';

@JS('Audio')
extension type _DomAudio._(JSObject _) implements JSObject {
  external factory _DomAudio();
  external set src(String value);
  external String get src;
  external set loop(bool value);
  external set volume(num value);
  external set currentTime(num value);
  external JSPromise<JSAny?> play();
  external void pause();
}

/// Direct HTMLAudioElement. just_audio on Chrome marks playing=true even when
/// play() is blocked, then later calls skip play() and stay silent at volume 0.
class WebBgmPlayer {
  _DomAudio? _audio;
  String? _src;

  _DomAudio get _element {
    final existing = _audio;
    if (existing != null) {
      return existing;
    }
    final created = _DomAudio()
      ..loop = true
      ..volume = 1;
    _audio = created;
    return created;
  }

  void prime() {
    final element = _element;
    if (_src == null || _src!.isEmpty) {
      element.src =
          'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAZGF0YQAAAAA=';
      _src = '__prime__';
    }
    element.play();
  }

  void preload(String url) {
    if (_src == url) {
      return;
    }
    _element
      ..loop = true
      ..src = url;
    _src = url;
  }

  void setVolume(double volume) {
    _element.volume = volume.clamp(0, 1);
  }

  Future<void> playUrl(String url, double volume) async {
    final element = _element
      ..loop = true
      ..volume = volume.clamp(0, 1);
    if (_src != url) {
      element.src = url;
      _src = url;
    }
    await element.play().toDart;
  }

  void stop() {
    final element = _audio;
    if (element == null) {
      return;
    }
    element.pause();
    element.currentTime = 0;
    _src = null;
  }
}
