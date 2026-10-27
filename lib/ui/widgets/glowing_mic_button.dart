import 'package:flutter/material.dart';
import '../theme/jarvis_theme.dart';

class GlowingMicButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final double size;

  const GlowingMicButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.size = 54.0,
  });

  @override
  State<GlowingMicButton> createState() => _GlowingMicButtonState();
}

class _GlowingMicButtonState extends State<GlowingMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isListening) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant GlowingMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !oldWidget.isListening) {
      _animController.repeat(reverse: true);
    } else if (!widget.isListening && oldWidget.isListening) {
      _animController.stop();
      _animController.animateTo(0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = widget.isListening ? _pulseAnimation.value : 1.0;
        final glowColor = widget.isListening
            ? JarvisTheme.emerald
            : JarvisTheme.cyan.withValues(alpha: 0.5);

        return GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: widget.size * 1.3,
            height: widget.size * 1.3,
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.isListening
                          ? [JarvisTheme.emerald, JarvisTheme.cyan]
                          : [
                              JarvisTheme.surfaceLight,
                              const Color(0xFF1B2838),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(
                          alpha: widget.isListening ? 0.6 : 0.25,
                        ),
                        blurRadius: widget.isListening ? 18 : 8,
                        spreadRadius: widget.isListening ? 4 : 1,
                      ),
                    ],
                    border: Border.all(
                      color: widget.isListening
                          ? JarvisTheme.emerald
                          : JarvisTheme.cyan.withValues(alpha: 0.5),
                      width: widget.isListening ? 2.0 : 1.2,
                    ),
                  ),
                  child: Icon(
                    widget.isListening ? Icons.mic : Icons.mic_none,
                    color: widget.isListening ? Colors.black : JarvisTheme.cyan,
                    size: widget.size * 0.48,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
