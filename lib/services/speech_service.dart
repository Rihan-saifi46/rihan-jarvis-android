import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechStatus { notInitialized, ready, listening, stopped, error, permissionDenied }

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  SpeechStatus _status = SpeechStatus.notInitialized;
  String _lastError = '';
  String? _selectedLocaleId;

  SpeechStatus get status => _status;
  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized && _speech.isAvailable;
  String get lastError => _lastError;

  /// Lazy initialization triggered ONLY when the user taps the microphone.
  /// This adheres strictly to the privacy-first principle.
  Future<bool> initialize({Function(SpeechStatus)? onStatusChanged}) async {
    if (_isInitialized) return true;

    try {
      final available = await _speech.initialize(
        onStatus: (statusStr) {
          if (kDebugMode) debugPrint('Speech status: $statusStr');
          if (statusStr == 'listening') {
            _status = SpeechStatus.listening;
          } else if (statusStr == 'notListening' || statusStr == 'done') {
            _status = SpeechStatus.ready;
          }
          onStatusChanged?.call(_status);
        },
        onError: (SpeechRecognitionError error) {
          if (kDebugMode) debugPrint('Speech error: ${error.errorMsg}');
          _lastError = error.errorMsg;
          if (error.errorMsg.toLowerCase().contains('permission') ||
              error.permanent) {
            _status = SpeechStatus.permissionDenied;
          } else {
            _status = SpeechStatus.error;
          }
          onStatusChanged?.call(_status);
        },
        debugLogging: false,
      );

      _isInitialized = available;
      if (available) {
        _status = SpeechStatus.ready;
        // Check available locales to pick en_IN or system locale for optimal Hinglish/English
        final locales = await _speech.locales();
        for (final loc in locales) {
          if (loc.localeId == 'en_IN' || loc.localeId == 'en-IN') {
            _selectedLocaleId = loc.localeId;
            break;
          }
        }
        if (_selectedLocaleId == null) {
          for (final loc in locales) {
            if (loc.localeId.startsWith('en')) {
              _selectedLocaleId = loc.localeId;
              break;
            }
          }
        }
      } else {
        _status = SpeechStatus.permissionDenied;
      }
      onStatusChanged?.call(_status);
      return available;
    } catch (e) {
      _lastError = e.toString();
      _status = SpeechStatus.error;
      onStatusChanged?.call(_status);
      return false;
    }
  }

  /// Start listening for voice input.
  /// Calls [onResult] with partial and final transcription.
  Future<void> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(double soundLevel)? onSoundLevelChange,
    Function(SpeechStatus)? onStatusChanged,
  }) async {
    if (!_isInitialized) {
      final ready = await initialize(onStatusChanged: onStatusChanged);
      if (!ready) {
        throw Exception(
          _status == SpeechStatus.permissionDenied
              ? 'Microphone permission denied, Sir. Please allow audio recording in settings.'
              : 'Speech recognition engine is unavailable on this device.',
        );
      }
    }

    if (_speech.isListening) {
      await stopListening();
      return;
    }

    _lastError = '';
    _status = SpeechStatus.listening;
    onStatusChanged?.call(_status);

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        localeId: _selectedLocaleId,
      ),
    );
  }

  /// Stop listening and commit current recognized words.
  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
      _status = SpeechStatus.ready;
    }
  }

  /// Cancel listening immediately.
  Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
      _status = SpeechStatus.ready;
    }
  }
}
