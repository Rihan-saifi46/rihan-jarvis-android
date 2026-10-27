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

    // Initial greeting from JARVIS
    _messages.add(
      ChatMessage(
        id: 'initial-greeting',
        text:
            'Greetings, Sir. J.A.R.V.I.S. is online and ready. How may I assist you today?',
        sender: MessageSender.jarvis,
        timestamp: DateTime.now(),
      ),
    );

    // Setup TTS listener
    _ttsService.onSpeakingStateChanged = (speaking) {
      if (mounted) setState(() {});
    };

    // Pre-initialize TTS silently in background
    _ttsService.initialize();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _glowController.dispose();
    _speechService.stopListening();
    _ttsService.stop();
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

  /// Toggle Speech-to-Text listening
  Future<void> _toggleVoiceInput() async {
    // If TTS is currently speaking, stop it so mic doesn't catch own voice
    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    if (_isListening) {
      await _speechService.stopListening();
      setState(() {
        _isListening = false;
      });
      return;
    }

    try {
      setState(() {
        _isListening = true;
        _listeningPreview = 'Listening to your voice, Sir...';
      });

      await _speechService.startListening(
        onResult: (recognizedWords, isFinal) {
          setState(() {
            _textController.text = recognizedWords;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
            _listeningPreview = recognizedWords.isNotEmpty
                ? recognizedWords
                : 'Listening to your voice, Sir...';

            if (isFinal) {
              _isListening = false;
            }
          });
        },
        onStatusChanged: (status) {
          if (status == SpeechStatus.ready || status == SpeechStatus.stopped) {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          } else if (status == SpeechStatus.permissionDenied) {
            if (mounted) {
              setState(() {
                _isListening = false;
              });
              _showPermissionDeniedDialog();
            }
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
          'Please grant microphone permission to enable speech recognition.',
          style: TextStyle(color: JarvisTheme.textSecondary, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(color: JarvisTheme.emerald)),
          ),
        ],
      ),
    );
  }

  /// Send message to JARVIS
  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty || _isAiResponding) return;

    // Stop listening if active
    if (_isListening) {
      await _speechService.stopListening();
      setState(() => _isListening = false);
    }

    // Stop speaking if currently speaking
    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
      isVoice: _listeningPreview.isNotEmpty && _listeningPreview == text,
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

      final jarvisMsgId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
      final jarvisMessage = ChatMessage(
        id: jarvisMsgId,
        text: aiResponse.reply,
        sender: MessageSender.jarvis,
        timestamp: DateTime.now(),
        actionData: aiResponse.actionData,
      );

      setState(() {
        _messages.add(jarvisMessage);
        _isAiResponding = false;
      });

      _scrollToBottom();

      // Speak response aloud if not muted
      if (!_isMuted) {
        await _ttsService.speak(aiResponse.reply);
      }

      // Execute action if an allowable Android action was dispatched
      if (aiResponse.isAction && aiResponse.actionData != null) {
        // Brief pause so user hears TTS / sees the message before app transition
        await Future.delayed(const Duration(milliseconds: 600));
        final actionResult = await ActionService.execute(aiResponse.actionData!);

        final updatedAction = aiResponse.actionData!.copyWith(
          isExecuted: true,
          isSuccess: actionResult.success,
          executionMessage: actionResult.message,
        );

        final idx = _messages.indexWhere((m) => m.id == jarvisMsgId);
        if (idx != -1 && mounted) {
          setState(() {
            _messages[idx] = _messages[idx].copyWith(actionData: updatedAction);
          });
        }
      }
    } catch (e) {
      final errorMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        text: e.toString().replaceAll('Exception: ', ''),
        sender: MessageSender.jarvis,
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
      final res = await ActionService.execute(msg.actionData!);
      if (!res.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message),
            backgroundColor: JarvisTheme.surface,
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
            child: const Text('Cancel', style: TextStyle(color: JarvisTheme.textSecondary)),
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
                    sender: MessageSender.jarvis,
                    timestamp: DateTime.now(),
                  ),
                );
              });
            },
            child: const Text('Clear', style: TextStyle(color: JarvisTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
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
                    onReplayAudio: msg.isJarvis && !_isMuted
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

            // Voice listening wave bar
            if (_isListening)
              VoiceWaveIndicator(
                isListening: _isListening,
                statusText: _listeningPreview,
                onCancel: () async {
                  await _speechService.stopListening();
                  setState(() => _isListening = false);
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
                'J.A.R.V.I.S.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: JarvisTheme.textPrimary,
                ),
              ),
              Text(
                'AI BRAIN • PHASE 1 ONLINE',
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
        // TTS Speaking Indicator / Mute Toggle
        IconButton(
          tooltip: _isMuted ? 'Unmute voice' : 'Mute voice',
          icon: Icon(
            _isMuted
                ? Icons.volume_off
                : (_ttsService.isSpeaking ? Icons.volume_up : Icons.volume_down),
            color: _isMuted ? JarvisTheme.textMuted : JarvisTheme.cyan,
            size: 22,
          ),
          onPressed: _toggleMute,
        ),
        // Settings / Server Config
        IconButton(
          tooltip: 'Core Settings',
          icon: const Icon(
            Icons.tune_outlined,
            color: JarvisTheme.textSecondary,
            size: 22,
          ),
          onPressed: _showSettings,
        ),
        // Clear chat
        IconButton(
          tooltip: 'Clear Log',
          icon: const Icon(
            Icons.delete_outline,
            color: JarvisTheme.textSecondary,
            size: 22,
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
            'JARVIS is processing neural request...',
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
          // Circular Glowing Microphone Button
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
                        : 'Message JARVIS (English or Hinglish)...',
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
              onPressed: hasText && !_isAiResponding ? () => _sendMessage() : null,
            ),
          ),
        ],
      ),
    );
  }
}
