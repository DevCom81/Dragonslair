import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

void initWindowsAudio() {
  if (!Platform.isWindows) {
    return;
  }
  JustAudioMediaKit.title = 'DragonsLair';
  JustAudioMediaKit.ensureInitialized(
    linux: false,
    windows: true,
  );
}
