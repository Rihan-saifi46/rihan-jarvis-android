import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../services/action_service.dart';
import '../../services/ai_service.dart';
import '../../services/speech_service.dart';
import '../../services/tts_service.dart';
import 'theme/jarvis_theme.dart';
import 'widgets/glowing_mic_button.dart';
import 'widgets/message_bubble.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/voice_wave_indicator.dart';

enum WakeWordPhase {
  idle,
  listeningForWakeWord,
  acknowledged,
  capturingCommand,
  processing,
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  final AiService _aiService = AiService();
  final SpeechService _speechService = SpeechService();
  final TtsService _ttsService = TtsService();

  bool _isAiResponding = false;
  bool _isListening = false;
  bool _isMuted = false;
  String _listeningPreview = '';

  // Phase 4A & 4B State
  bool _isSubmittingVoiceCommand = false;
  bool _isHeyMickeyMode = false;
  WakeWordPhase _wakeWordPhase = WakeWordPhase.idle;
  Timer? _wakeWordLoopTimer;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation for header reactor orb
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Initial greeting from Mickey
    _messages.add(
      ChatMessage(
        id: 'initial-greeting',
        text:
            'Greetings, Sir. Mickey is online and ready. How may I assist you today?',
        sender: MessageSender.mickey,
        timestamp: DateTime.now(),
      ),
    );

    // Setup TTS listener & prevent mic from hearing TTS playback
    _ttsService.onSpeakingStateChanged = (speaking) {
      if (speaking && _speechService.isListening) {
        _speechService.stopListening();
      }
      if (mounted) setState(() {});
    };

    // Pre-initialize TTS silently in background
    _ttsService.initialize();
  }

  @override
  void dispose() {
    _wakeWordLoopTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _glowController.dispose();
    _speechService.stopListening();
    _ttsService.stop();
    if (_isHeyMickeyMode) {
      ActionService.stopMickeyService();
    }
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================
  // PHASE 4A: FOREGROUND VOICE COMMAND MODE
  // ==========================================

  /// Toggle Speech-to-Text listening for immediate command
  Future<void> _toggleVoiceInput() async {
    // If TTS is currently speaking, stop it so mic doesn't catch own voice
    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    if (_isListening) {
      await _speechService.stopListening();
      setState(() {
        _isListening = false;
        _listeningPreview = '';
      });
      return;
    }

    try {
      setState(() {
        _isListening = true;
        _listeningPreview = 'Listening to your voice, Sir...';
      });

      await _speechService.startListening(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onResult: (recognizedWords, isFinal) {
          if (!mounted) return;
          setState(() {
            _textController.text = recognizedWords;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
            _listeningPreview = recognizedWords.isNotEmpty
                ? recognizedWords
                : 'Listening to your voice, Sir...';
          });

          // Phase 4A Auto-Submit: Auto finalize command once speech finishes
          if (isFinal && recognizedWords.trim().isNotEmpty) {
            _handleVoiceCommandFinalized(recognizedWords.trim());
          }
        },
        onStatusChanged: (status) {
          if (!mounted) return;
          if (status == SpeechStatus.ready || status == SpeechStatus.stopped) {
            final text = _textController.text.trim();
            // If stopped and text was transcribed but not yet submitted
            if (_isListening && text.isNotEmpty && !_isSubmittingVoiceCommand) {
              _handleVoiceCommandFinalized(text);
            } else {
              setState(() {
                _isListening = false;
              });
            }
          } else if (status == SpeechStatus.permissionDenied) {
            setState(() {
              _isListening = false;
            });
            _showPermissionDeniedDialog();
          }
        },
      );
    } catch (e) {
      setState(() {
        _isListening = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: JarvisTheme.surfaceLight,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Automatically submit voice command without requiring user to tap Send
  Future<void> _handleVoiceCommandFinalized(String spokenText) async {
    if (_isSubmittingVoiceCommand || spokenText.trim().isEmpty) return;
    _isSubmittingVoiceCommand = true;

    try {
      await _speechService.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
          _listeningPreview = '';
        });
      }

      // Automatically strip wake word if user said "Hey Mickey, open YouTube"
      final cleanCommand = SpeechService.stripWakeWord(spokenText);
      final commandToSend = cleanCommand.isNotEmpty ? cleanCommand : spokenText;

      await _sendMessage(commandToSend, true);
    } catch (e) {
      debugPrint('[ChatScreen] Auto-submit error: $e');
    } finally {
      _isSubmittingVoiceCommand = false;
    }
  }

  // ==========================================
  // PHASE 4B: "HEY MICKEY" WAKE WORD & BACKGROUND
  // ==========================================

  /// Toggle "Hey Mickey" continuous local wake-word mode
  Future<void> _toggleHeyMickeyMode() async {
    if (_isHeyMickeyMode) {
      await _stopHeyMickeyMode();
      return;
    }

    // Verify microphone availability
    final available = await _speechService.initialize();
    if (!available) {
      _showPermissionDeniedDialog();
      return;
    }

    // If speaking, stop TTS
    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }
    // If standard mic was listening, stop it
    if (_isListening) {
      await _speechService.stopListening();
      _isListening = false;
    }

    setState(() {
      _isHeyMickeyMode = true;
      _wakeWordPhase = WakeWordPhase.listeningForWakeWord;
    });

    // Start native Android foreground service with notification
    try {
      await ActionService.startMickeyService();
    } catch (e) {
      debugPrint('[ChatScreen] Could not start MickeyService: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hey Mickey mode active. Listening locally for "Hey Mickey"...',
            style: TextStyle(color: JarvisTheme.emerald),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: JarvisTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _runWakeWordCycle();
  }

  /// Stop "Hey Mickey" wake-word listening and dismiss foreground service
  Future<void> _stopHeyMickeyMode() async {
    _wakeWordLoopTimer?.cancel();
    _wakeWordLoopTimer = null;

    setState(() {
      _isHeyMickeyMode = false;
      _wakeWordPhase = WakeWordPhase.idle;
    });

    await _speechService.stopListening();

    try {
      await ActionService.stopMickeyService();
    } catch (e) {
      debugPrint('[ChatScreen] Could not stop MickeyService: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hey Mickey mode stopped.',
            style: TextStyle(color: JarvisTheme.textSecondary),
          ),
          duration: Duration(seconds: 1),
          backgroundColor: JarvisTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Run an iterative local wake-word listening cycle
  Future<void> _runWakeWordCycle() async {
    if (!_isHeyMickeyMode || !mounted) return;

    // Do not listen while Mickey is speaking or responding to avoid feedback
    if (_ttsService.isSpeaking || _isAiResponding || _isSubmittingVoiceCommand) {
      _wakeWordLoopTimer?.cancel();
      _wakeWordLoopTimer = Timer(const Duration(milliseconds: 600), () {
        if (_isHeyMickeyMode && mounted) {
          _runWakeWordCycle();
        }
      });
      return;
    }

    setState(() {
      _wakeWordPhase = WakeWordPhase.listeningForWakeWord;
    });

    try {
      await _speechService.startListening(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 2),
        onResult: (words, isFinal) async {
          if (!_isHeyMickeyMode || !mounted) return;
          final trimmed = words.trim();
          if (trimmed.isEmpty) return;

          // Check if user said the wake word
          if (SpeechService.containsWakeWord(trimmed)) {
            final strippedCommand = SpeechService.stripWakeWord(trimmed);
            await _speechService.stopListening();

            if (strippedCommand.isNotEmpty) {
              // Case A: User said wake word + command together (e.g. "Hey Mickey, open YouTube")
              setState(() {
                _wakeWordPhase = WakeWordPhase.processing;
              });
              await _sendMessage(strippedCommand, true);
              if (_isHeyMickeyMode && mounted) {
                _wakeWordLoopTimer?.cancel();
                _wakeWordLoopTimer = Timer(const Duration(milliseconds: 800), () {
                  if (_isHeyMickeyMode && mounted) _runWakeWordCycle();
                });
              }
            } else {
              // Case B: Standalone wake word (e.g. "Hey Mickey")
              await _handleStandaloneWakeWord();
            }
          }
        },
        onStatusChanged: (status) {
          if (status == SpeechStatus.ready || status == SpeechStatus.stopped) {
            if (_isHeyMickeyMode &&
                _wakeWordPhase == WakeWordPhase.listeningForWakeWord &&
                mounted) {
              _wakeWordLoopTimer?.cancel();
              _wakeWordLoopTimer = Timer(const Duration(milliseconds: 400), () {
                if (_isHeyMickeyMode &&
                    _wakeWordPhase == WakeWordPhase.listeningForWakeWord &&
                    mounted) {
                  _runWakeWordCycle();
                }
              });
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[ChatScreen] Wake word cycle error: $e');
      if (_isHeyMickeyMode && mounted) {
        _wakeWordLoopTimer?.cancel();
        _wakeWordLoopTimer = Timer(const Duration(seconds: 1), () {
          if (_isHeyMickeyMode && mounted) _runWakeWordCycle();
        });
      }
    }
  }

  /// Handle standalone wake word ("Hey Mickey" without command)
  Future<void> _handleStandaloneWakeWord() async {
    if (!_isHeyMickeyMode || !mounted) return;

    setState(() {
      _wakeWordPhase = WakeWordPhase.acknowledged;
    });

    const ackReply = "Yes Sir? I'm listening.";
    final ackMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: ackReply,
      sender: MessageSender.mickey,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(ackMessage);
    });
    _scrollToBottom();

    // Speak acknowledgment aloud
    if (!_isMuted) {
      await _ttsService.speak(ackReply);
      await Future.delayed(const Duration(milliseconds: 1300));
    }

    if (!_isHeyMickeyMode || !mounted) return;

    // Capture the follow-up command
    setState(() {
      _wakeWordPhase = WakeWordPhase.capturingCommand;
    });

    try {
      await _speechService.startListening(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
        onResult: (cmdWords, isFinal) async {
          if (!_isHeyMickeyMode || !mounted) return;
          if (isFinal && cmdWords.trim().isNotEmpty) {
            await _speechService.stopListening();
            final clean = SpeechService.stripWakeWord(cmdWords.trim());
            final finalCmd = clean.isNotEmpty ? clean : cmdWords.trim();

            setState(() {
              _wakeWordPhase = WakeWordPhase.processing;
            });

            await _sendMessage(finalCmd, true);

            if (_isHeyMickeyMode && mounted) {
              _wakeWordLoopTimer?.cancel();
              _wakeWordLoopTimer = Timer(const Duration(milliseconds: 800), () {
                if (_isHeyMickeyMode && mounted) _runWakeWordCycle();
              });
            }
          }
        },
        onStatusChanged: (status) {
          if (status == SpeechStatus.ready || status == SpeechStatus.stopped) {
            if (_isHeyMickeyMode &&
                _wakeWordPhase == WakeWordPhase.capturingCommand &&
                mounted) {
              // If user didn't speak a command, smoothly return to wake-word standby
              _wakeWordLoopTimer?.cancel();
              _wakeWordLoopTimer = Timer(const Duration(milliseconds: 400), () {
                if (_isHeyMickeyMode && mounted) _runWakeWordCycle();
              });
            }
          }
        },
      );
    } catch (e) {
      debugPrint('[ChatScreen] Error capturing command after wake word: $e');
      if (_isHeyMickeyMode && mounted) {
        _runWakeWordCycle();
      }
    }
  }

  // ==========================================
  // SEND MESSAGE & ACTION EXECUTION
  // ==========================================

  /// Send message to Mickey (typed or voice)
  Future<void> _sendMessage([String? overrideText, bool isVoiceInput = false]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty || _isAiResponding) return;

    // Stop listening if active
    if (_isListening || _speechService.isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
    }

    // Stop speaking if currently speaking
    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    final isVoice = isVoiceInput ||
        (_listeningPreview.isNotEmpty && _listeningPreview == text);

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      isVoice: isVoice,
    );

    setState(() {
      _messages.add(userMessage);
      _textController.clear();
      _listeningPreview = '';
      _isAiResponding = true;
    });

    _scrollToBottom();

    try {
      final aiResponse = await _aiService.sendMessageWithAction(
        message: text,
        history: _messages,
      );

      final mickeyMsgId =
          (DateTime.now().millisecondsSinceEpoch + 1).toString();
      final mickeyMessage = ChatMessage(
        id: mickeyMsgId,
        text: aiResponse.reply,
        sender: MessageSender.mickey,
        timestamp: DateTime.now(),
        actionData: aiResponse.actionData,
      );

      setState(() {
        _messages.add(mickeyMessage);
        _isAiResponding = false;
      });

      _scrollToBottom();

      // Speak response aloud if not muted (non-blocking)
      if (!_isMuted) {
        _ttsService.speak(aiResponse.reply).catchError((e) {
          debugPrint('[ChatScreen] TTS speak error: $e');
        });
      }

      // Execute action if an allowable Android action was dispatched
      if (aiResponse.isAction && aiResponse.actionData != null) {
        debugPrint(
            '[ChatScreen] Auto-executing action: "${aiResponse.actionData!.action}"');
        // Brief pause so the message appears on screen before app transition
        await Future.delayed(const Duration(milliseconds: 400));
        final actionResult =
            await ActionService.execute(aiResponse.actionData!);
        debugPrint(
            '[ChatScreen] ActionResult: success=${actionResult.success}, msg="${actionResult.message}"');

        final updatedAction = aiResponse.actionData!.copyWith(
          isExecuted: true,
          isSuccess: actionResult.success,
          executionMessage: actionResult.message,
        );

        final idx = _messages.indexWhere((m) => m.id == mickeyMsgId);
        if (idx != -1 && mounted) {
          setState(() {
            _messages[idx] =
                _messages[idx].copyWith(actionData: updatedAction);
          });
        }

        if (!actionResult.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Action failed: ${actionResult.message}',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: JarvisTheme.errorRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: e.toString().replaceAll('Exception: ', ''),
        sender: MessageSender.mickey,
        timestamp: DateTime.now(),
        status: MessageStatus.error,
      );

      setState(() {
        _messages.add(errorMessage);
        _isAiResponding = false;
      });

      _scrollToBottom();
    }
  }

  Future<void> _relaunchAction(ChatMessage msg) async {
    if (msg.actionData != null) {
      debugPrint(
          '[ChatScreen] Manual tap re-executing action: "${msg.actionData!.action}"');
      final res = await ActionService.execute(msg.actionData!);
      debugPrint(
          '[ChatScreen] Manual relaunch result: success=${res.success}, msg="${res.message}"');

      final updated = msg.actionData!.copyWith(
        isExecuted: true,
        isSuccess: res.success,
        executionMessage: res.message,
      );

      final idx = _messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1 && mounted) {
        setState(() {
          _messages[idx] = _messages[idx].copyWith(actionData: updated);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.success ? res.message : 'Action failed: ${res.message}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor:
                res.success ? JarvisTheme.surface : JarvisTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleMute() {
    _ttsService.toggleMute();
    setState(() {
      _isMuted = _ttsService.isMuted;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMuted ? 'Voice output muted, Sir.' : 'Voice output enabled, Sir.',
          style: const TextStyle(color: JarvisTheme.textPrimary),
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: JarvisTheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsSheet(
        onSettingsChanged: () {
          setState(() {});
        },
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JarvisTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: JarvisTheme.surfaceBorder),
        ),
        title: const Text(
          'Clear Memory Log?',
          style: TextStyle(color: JarvisTheme.textPrimary, fontSize: 16),
        ),
        content: const Text(
          'This will clear our current conversational buffer, Sir.',
          style: TextStyle(color: JarvisTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: JarvisTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    text: 'Memory buffer cleared. How may I assist you now, Sir?',
                    sender: MessageSender.mickey,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            },
            child: const Text('Clear',
                style: TextStyle(color: JarvisTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JarvisTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: JarvisTheme.cyanDim),
        ),
        title: const Row(
          children: [
            Icon(Icons.mic_off, color: JarvisTheme.cyan),
            SizedBox(width: 8),
            Text(
              'Microphone Permission',
              style: TextStyle(color: JarvisTheme.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Sir, microphone access is required for voice interactions.\n'
          'Please grant microphone permission in device settings to enable speech recognition.',
          style: TextStyle(color: JarvisTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood',
                style: TextStyle(color: JarvisTheme.emerald)),
          ),
        ],
      ),
    );
  }

  void _showHyperOsGuidanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: JarvisTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: JarvisTheme.cyanDim),
        ),
        title: const Row(
          children: [
            Icon(Icons.settings_suggest_outlined, color: JarvisTheme.cyan),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'POCO M7 Plus / HyperOS Setup',
                style: TextStyle(color: JarvisTheme.textPrimary, fontSize: 15),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'For Mickey to listen reliably in the background on Xiaomi HyperOS, configure these Android settings:',
                style: TextStyle(
                    color: JarvisTheme.textSecondary, fontSize: 13),
              ),
              SizedBox(height: 12),
              _HyperOsStepTile(
                step: '1',
                title: 'Battery Saver: No Restrictions',
                desc:
                    'Settings → Apps → Mickey → Battery Saver → Choose "No restrictions" so the mic is not killed in the background.',
              ),
              SizedBox(height: 8),
              _HyperOsStepTile(
                step: '2',
                title: 'Autostart Permission',
                desc:
                    'Settings → Apps → Mickey → Enable "Autostart" so Mickey can start with the device.',
              ),
              SizedBox(height: 8),
              _HyperOsStepTile(
                step: '3',
                title: 'Notifications Allowed',
                desc:
                    'Android 13+ requires notifications to show the persistent "Mickey is listening" status.',
              ),
              SizedBox(height: 8),
              _HyperOsStepTile(
                step: '4',
                title: 'Lock App in Recent Tasks',
                desc:
                    'Open Recent Apps, long press Mickey, and tap the Padlock icon to prevent HyperOS task killer.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood',
                style: TextStyle(color: JarvisTheme.emerald)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD METHOD & UI WIDGETS
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Active Wake Word Status Banner
            if (_isHeyMickeyMode) _buildWakeWordStatusBar(),

            // Conversation messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return MessageBubble(
                    message: msg,
                    onReplayAudio: msg.isMickey && !_isMuted
                        ? () => _ttsService.speak(msg.text)
                        : null,
                    onReplayAction: msg.actionData != null
                        ? () => _relaunchAction(msg)
                        : null,
                    onRetry: msg.status == MessageStatus.error
                        ? () {
                            final lastUserMsg = _messages.lastWhere(
                              (m) => m.isUser,
                              orElse: () => msg,
                            );
                            if (lastUserMsg.isUser) {
                              _sendMessage(lastUserMsg.text);
                            }
                          }
                        : null,
                  );
                },
              ),
            ),

            // AI Computing / Thinking Holographic Indicator
            if (_isAiResponding) _buildThinkingIndicator(),

            // Voice listening wave bar for Phase 4A
            if (_isListening)
              VoiceWaveIndicator(
                isListening: _isListening,
                statusText: _listeningPreview,
                onCancel: () async {
                  await _speechService.stopListening();
                  setState(() {
                    _isListening = false;
                    _listeningPreview = '';
                  });
                },
              ),

            // Bottom Input Controls
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          // Holographic Core Indicator
          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: JarvisTheme.emerald,
                  boxShadow: [
                    BoxShadow(
                      color: JarvisTheme.emerald.withValues(
                        alpha: _glowAnimation.value * 0.8,
                      ),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MICKEY',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: JarvisTheme.textPrimary,
                ),
              ),
              Text(
                'VOICE AI • PHASE 4 ONLINE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: JarvisTheme.cyan,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // "Hey Mickey" Wake Word Toggle Button
        _buildWakeWordToggleButton(),

        // HyperOS Guidance Info Button
        IconButton(
          tooltip: 'POCO/HyperOS Settings',
          icon: const Icon(
            Icons.help_outline,
            color: JarvisTheme.textSecondary,
            size: 20,
          ),
          onPressed: _showHyperOsGuidanceDialog,
        ),

        // TTS Speaking Indicator / Mute Toggle
        IconButton(
          tooltip: _isMuted ? 'Unmute voice' : 'Mute voice',
          icon: Icon(
            _isMuted
                ? Icons.volume_off
                : (_ttsService.isSpeaking
                    ? Icons.volume_up
                    : Icons.volume_down),
            color: _isMuted ? JarvisTheme.textMuted : JarvisTheme.cyan,
            size: 21,
          ),
          onPressed: _toggleMute,
        ),

        // Settings / Server Config
        IconButton(
          tooltip: 'Core Settings',
          icon: const Icon(
            Icons.tune_outlined,
            color: JarvisTheme.textSecondary,
            size: 21,
          ),
          onPressed: _showSettings,
        ),

        // Clear chat
        IconButton(
          tooltip: 'Clear Log',
          icon: const Icon(
            Icons.delete_outline,
            color: JarvisTheme.textSecondary,
            size: 21,
          ),
          onPressed: _clearChat,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: JarvisTheme.surfaceBorder.withValues(alpha: 0.5),
          height: 1.0,
        ),
      ),
    );
  }

  /// AppBar Toggle Chip for "Hey Mickey" Wake-Word Mode
  Widget _buildWakeWordToggleButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: InkWell(
        onTap: _toggleHeyMickeyMode,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _isHeyMickeyMode
                ? JarvisTheme.emerald.withValues(alpha: 0.2)
                : JarvisTheme.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHeyMickeyMode
                  ? JarvisTheme.emerald
                  : JarvisTheme.surfaceBorder,
              width: 1.2,
            ),
            boxShadow: _isHeyMickeyMode
                ? [
                    BoxShadow(
                      color: JarvisTheme.emerald.withValues(alpha: 0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isHeyMickeyMode
                    ? Icons.record_voice_over
                    : Icons.mic_none,
                size: 14,
                color: _isHeyMickeyMode
                    ? JarvisTheme.emerald
                    : JarvisTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                _isHeyMickeyMode ? 'MICKEY ON' : 'Hey Mickey',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: _isHeyMickeyMode
                      ? JarvisTheme.emerald
                      : JarvisTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Persistent Banner displaying Wake Word State and Quick Stop
  Widget _buildWakeWordStatusBar() {
    String statusText;
    Color accentColor = JarvisTheme.emerald;

    switch (_wakeWordPhase) {
      case WakeWordPhase.listeningForWakeWord:
        statusText = 'Listening locally for "Hey Mickey"...';
        accentColor = JarvisTheme.emerald;
        break;
      case WakeWordPhase.acknowledged:
        statusText = 'Mickey: "Yes Sir? I\'m listening."';
        accentColor = JarvisTheme.cyan;
        break;
      case WakeWordPhase.capturingCommand:
        statusText = 'Mickey is capturing command: Speak now, Sir...';
        accentColor = JarvisTheme.cyan;
        break;
      case WakeWordPhase.processing:
        statusText = 'Processing neural request...';
        accentColor = JarvisTheme.cyan;
        break;
      case WakeWordPhase.idle:
        statusText = 'Hey Mickey standby';
        accentColor = JarvisTheme.textSecondary;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: JarvisTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: accentColor.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _stopHeyMickeyMode,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: JarvisTheme.errorRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: JarvisTheme.errorRed.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              child: const Text(
                'STOP',
                style: TextStyle(
                  color: JarvisTheme.errorRed,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: JarvisTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: JarvisTheme.cyan.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(JarvisTheme.cyan),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Mickey is processing neural request...',
            style: TextStyle(
              color: JarvisTheme.cyan,
              fontSize: 12,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: JarvisTheme.surface,
        border: Border(
          top: BorderSide(
            color: JarvisTheme.surfaceBorder.withValues(alpha: 0.8),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Circular Glowing Microphone Button (Phase 4A)
          GlowingMicButton(
            isListening: _isListening,
            onTap: _toggleVoiceInput,
            size: 48,
          ),
          const SizedBox(width: 8),

          // Text Field Container
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 46,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: JarvisTheme.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isListening
                      ? JarvisTheme.emerald.withValues(alpha: 0.6)
                      : JarvisTheme.surfaceBorder,
                  width: 1.2,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: TextField(
                  controller: _textController,
                  focusNode: _inputFocusNode,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    color: JarvisTheme.textPrimary,
                    fontSize: 14.5,
                  ),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Listening to your voice, Sir...'
                        : 'Message Mickey (English or Hinglish)...',
                    hintStyle: const TextStyle(
                      color: JarvisTheme.textMuted,
                      fontSize: 13.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasText ? JarvisTheme.coreGradient : null,
              color: hasText ? null : JarvisTheme.surfaceLight,
              border: Border.all(
                color: hasText
                    ? JarvisTheme.emerald
                    : JarvisTheme.surfaceBorder,
                width: 1.2,
              ),
              boxShadow: hasText
                  ? [
                      BoxShadow(
                        color: JarvisTheme.emerald.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              icon: Icon(
                Icons.send_rounded,
                size: 20,
                color: hasText ? Colors.black : JarvisTheme.textMuted,
              ),
              onPressed:
                  hasText && !_isAiResponding ? () => _sendMessage() : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _HyperOsStepTile extends StatelessWidget {
  final String step;
  final String title;
  final String desc;

  const _HyperOsStepTile({
    required this.step,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: JarvisTheme.cyanDim,
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: JarvisTheme.cyan,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: JarvisTheme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  color: JarvisTheme.textMuted,
                  fontSize: 11.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
