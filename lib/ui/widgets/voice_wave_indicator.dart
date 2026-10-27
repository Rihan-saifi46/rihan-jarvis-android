import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/jarvis_theme.dart';

class VoiceWaveIndicator extends StatefulWidget {
  final bool isListening;
  final String statusText;
  final VoidCallback? onCancel;

  const VoiceWaveIndicator({
    super.key,
    required this.isListening,
    this.statusText = 'Listening to your voice, Sir...',
    this.onCancel,
  });

  @override
  State<VoiceWaveIndicator> createState() => _VoiceWaveIndicatorState();
}

class _VoiceWaveIndicatorState extends State<VoiceWaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isListening) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: JarvisTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: JarvisTheme.emerald.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: JarvisTheme.emerald.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Audio frequency wave bars
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                children: List.generate(5, (index) {
                  final animVal = sin((_controller.value * 2 * pi) + (index * 0.8)).abs();
                  final height = 8.0 + (animVal * 16.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 3.5,
                    height: height,
                    decoration: BoxDecoration(
                      color: index.isEven ? JarvisTheme.emerald : JarvisTheme.cyan,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.statusText,
              style: const TextStyle(
                color: JarvisTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onCancel != null)
            GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: JarvisTheme.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
