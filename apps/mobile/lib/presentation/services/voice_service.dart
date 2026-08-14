import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around the device-native text-to-speech engine. Announcements
/// are queued and never repeat the same instruction twice. Honours a global
/// mute switch. Fails softly: if TTS is unavailable, navigation continues
/// silently (voice is an enhancement, never a blocker).
class VoiceService {
  VoiceService() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  bool _muted = false;
  String? _lastSpoken;
  bool _ready = false;

  Future<void> _init() async {
    try {
      await _tts.setLanguage('en');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  bool get muted => _muted;
  set muted(bool value) {
    _muted = value;
    if (value) {
      _tts.stop();
    }
  }

  void setMuted(bool value) => muted = value;

  /// Speaks [message] unless it was already spoken this session. Returns the
  /// spoken message, or null when skipped (muted / duplicate / unavailable).
  Future<String?> announce(String message) async {
    if (_muted || !_ready) return null;
    if (message == _lastSpoken) return null;
    _lastSpoken = message;
    try {
      await _tts.speak(message);
      return message;
    } catch (_) {
      return null;
    }
  }

  void stop() {
    _tts.stop();
  }
}

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService();
  ref.onDispose(service.stop);
  return service;
});