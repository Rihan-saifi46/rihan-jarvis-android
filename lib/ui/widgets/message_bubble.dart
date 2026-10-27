import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../theme/jarvis_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onReplayAudio;
  final VoidCallback? onRetry;
  final VoidCallback? onReplayAction;

  const MessageBubble({
    super.key,
    required this.message,
    this.onReplayAudio,
    this.onRetry,
    this.onReplayAction,
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
                maxWidth: MediaQuery.of(context).size.width * 0.82,
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
                        isUser ? 'YOU' : 'MICKEY',
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

                  // Action Badge Card if action detected
                  if (message.actionData != null) ...[
                    const SizedBox(height: 8),
                    _buildActionCard(message.actionData!),
                  ],

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

  Widget _buildActionCard(ActionData action) {
    IconData icon;
    String actionTitle;
    String actionDetail;
    String? actionSubDetail;
    Color accentColor;
    String buttonLabel = 'OPEN';
    String readyStatus = 'ACTION READY';

    switch (action.action) {
      case 'youtube_search':
        icon = Icons.play_circle_fill;
        actionTitle = 'YOUTUBE SEARCH';
        actionDetail = action.query ?? '';
        accentColor = const Color(0xFFFF4B6E);
        break;
      case 'google_search':
        icon = Icons.travel_explore;
        actionTitle = 'GOOGLE SEARCH';
        actionDetail = action.query ?? '';
        accentColor = JarvisTheme.emerald;
        break;
      case 'open_app':
        icon = Icons.open_in_new_rounded;
        actionTitle = 'OPEN APPLICATION';
        actionDetail = action.app?.toUpperCase() ?? '';
        accentColor = JarvisTheme.cyan;
        break;
      case 'make_call':
        icon = Icons.call;
        actionTitle = 'PHONE CALL';
        actionDetail = action.phoneNumber ?? '';
        accentColor = const Color(0xFF00E676);
        buttonLabel = 'CALL';
        readyStatus = 'OPENING DIALER';
        break;
      case 'send_sms':
        icon = Icons.sms_outlined;
        actionTitle = 'SMS MESSAGE';
        actionDetail = action.phoneNumber != null ? 'To: ${action.phoneNumber}' : '';
        if (action.message != null && action.message!.trim().isNotEmpty) {
          actionSubDetail = '"${action.message!.trim()}"';
        }
        accentColor = const Color(0xFFFFB300);
        buttonLabel = 'SMS';
        readyStatus = 'OPENING SMS';
        break;
      case 'open_whatsapp':
        icon = Icons.chat_bubble_outline_rounded;
        actionTitle = 'WHATSAPP';
        actionDetail = action.phoneNumber != null
            ? (action.phoneNumber!.startsWith('+') ? 'To: ${action.phoneNumber}' : 'To: +${action.phoneNumber}')
            : '';
        if (action.message != null && action.message!.trim().isNotEmpty) {
          actionSubDetail = '"${action.message!.trim()}"';
        }
        accentColor = const Color(0xFF25D366);
        buttonLabel = 'CHAT';
        readyStatus = 'OPENING WHATSAPP';
        break;
      default:
        icon = Icons.bolt;
        actionTitle = 'SYSTEM ACTION';
        actionDetail = action.action;
        accentColor = JarvisTheme.cyan;
    }

    final isSuccess = action.isSuccess == true;
    final isFailed = action.isSuccess == false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: JarvisTheme.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: actionSubDetail != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      actionTitle,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? JarvisTheme.emerald.withValues(alpha: 0.15)
                            : (isFailed
                                ? JarvisTheme.errorRed.withValues(alpha: 0.15)
                                : JarvisTheme.cyan.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isSuccess
                            ? 'EXECUTED'
                            : (isFailed ? 'FAILED' : readyStatus),
                        style: TextStyle(
                          color: isSuccess
                              ? JarvisTheme.emerald
                              : (isFailed ? JarvisTheme.errorRed : JarvisTheme.cyan),
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  actionDetail,
                  style: const TextStyle(
                    color: JarvisTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (actionSubDetail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    actionSubDetail,
                    style: const TextStyle(
                      color: JarvisTheme.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (isFailed && action.executionMessage != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    action.executionMessage!,
                    style: const TextStyle(
                      color: JarvisTheme.errorRed,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (onReplayAction != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onReplayAction,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: JarvisTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isFailed ? JarvisTheme.errorRed.withValues(alpha: 0.5) : JarvisTheme.surfaceBorder),
                ),
                child: Text(
                  isFailed ? 'RETRY' : (action.isExecuted ? 'RE-OPEN' : buttonLabel),
                  style: TextStyle(
                    color: isFailed ? JarvisTheme.errorRed : accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
