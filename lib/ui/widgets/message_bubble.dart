import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../theme/jarvis_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onReplayAudio;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.onReplayAudio,
    this.onRetry,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isError = message.status == MessageStatus.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // Holographic JARVIS Arc Reactor Avatar
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: JarvisTheme.coreGradient,
                boxShadow: [
                  BoxShadow(
                    color: JarvisTheme.emerald.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.black,
                  size: 16,
                ),
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: isUser
                    ? JarvisTheme.userBubbleGradient
                    : (isError
                        ? LinearGradient(
                            colors: [
                              JarvisTheme.errorRed.withValues(alpha: 0.15),
                              JarvisTheme.surface,
                            ],
                          )
                        : JarvisTheme.jarvisBubbleGradient),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: Border.all(
                  color: isError
                      ? JarvisTheme.errorRed.withValues(alpha: 0.4)
                      : (isUser
                          ? JarvisTheme.emerald.withValues(alpha: 0.3)
                          : JarvisTheme.cyan.withValues(alpha: 0.25)),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? JarvisTheme.emerald : JarvisTheme.cyan)
                        .withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Label header
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isVoice) ...[
                        Icon(
                          Icons.mic,
                          size: 12,
                          color: isUser
                              ? JarvisTheme.emerald
                              : JarvisTheme.cyan,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        isUser ? 'YOU' : 'JARVIS',
                        style: TextStyle(
                          color: isUser
                              ? JarvisTheme.emerald
                              : JarvisTheme.cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Message text
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: isError
                          ? JarvisTheme.errorRed
                          : JarvisTheme.textPrimary,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Footer: Timestamp + Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment:
                        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: const TextStyle(
                          color: JarvisTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                      if (!isUser && !isError && onReplayAudio != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onReplayAudio,
                          child: const Icon(
                            Icons.volume_up_outlined,
                            size: 15,
                            color: JarvisTheme.textSecondary,
                          ),
                        ),
                      ],
                      if (isError && onRetry != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onRetry,
                          child: const Row(
                            children: [
                              Icon(
                                Icons.refresh,
                                size: 14,
                                color: JarvisTheme.errorRed,
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Retry',
                                style: TextStyle(
                                  color: JarvisTheme.errorRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            // User Avatar indicator
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(left: 8, bottom: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: JarvisTheme.surfaceLight,
                border: Border.all(
                  color: JarvisTheme.emerald.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.person,
                  color: JarvisTheme.emerald,
                  size: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
