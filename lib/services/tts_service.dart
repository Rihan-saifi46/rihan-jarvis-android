import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isMuted = false;

  bool get isSpeaking => _isSpeaking;
  bool get isMuted => _isMuted;

  Function(bool speaking)? onSpeakingStateChanged;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure voice attributes for JARVIS persona
      await _flutterTts.setSpeechRate(0.5); // Natural, clear pace
      await _flutterTts.setPitch(0.95);     // Slightly lower, composed tone
      await _flutterTts.setVolume(1.0);

      // Best effort Indian English or standard English for Hinglish/English phonetics
      final languages = await _flutterTts.getLanguages;
      if (languages is List) {
        if (languages.contains('en-IN')) {
          await _flutterTts.setLanguage('en-IN');
        } else if (languages.contains('en-US')) {
          await _flutterTts.setLanguage('en-US');
        }
      }

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onSpeakingStateChanged?.call(true);
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
      });

      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
      });

      _flutterTts.setErrorHandler((dynamic message) {
        if (kDebugMode) debugPrint('TTS Error: $message');
        _isSpeaking = false;
        onSpeakingStateChanged?.call(false);
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS initialization warning: $e');
    }
  }

  /// Speak text aloud if unmuted.
  Future<void> speak(String text) async {
    if (_isMuted || text.trim().isEmpty) return;

    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Clean speech text to avoid robotic reading of markdown symbols
      final speechText = _sanitizeForSpeech(text);
      if (speechText.isEmpty) return;

      // Stop any existing speech first
      await _flutterTts.stop();
      await _flutterTts.speak(speechText);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
    }
  }

  /// Stop currently active speech immediately.
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      onSpeakingStateChanged?.call(false);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS stop error: $e');
    }
  }

  /// Toggle mute status. If turning mute ON, halts active speech.
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted && _isSpeaking) {
      stop();
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted && _isSpeaking) {
      stop();
    }
  }

  /// Remove markdown, URLs, symbols that TTS shouldn't pronounce
  String _sanitizeForSpeech(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceAll(RegExp(r'https?://\S+'), 'link');
    cleaned = cleaned.replaceAll(RegExp(r'[`*_#~>|]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1');
    return cleaned.trim();
  }
}
