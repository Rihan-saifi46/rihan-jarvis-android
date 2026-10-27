import 'package:flutter/material.dart';
import '../../services/ai_service.dart';
import '../theme/jarvis_theme.dart';

class SettingsSheet extends StatefulWidget {
  final VoidCallback? onSettingsChanged;

  const SettingsSheet({super.key, this.onSettingsChanged});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _urlController = TextEditingController();
  final _aiService = AiService();
  bool _testingConnection = false;
  String? _testResult;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = _aiService.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testLink() async {
    setState(() {
      _testingConnection = true;
      _testResult = null;
    });

    _aiService.setBaseUrl(_urlController.text);
    final health = await _aiService.checkHealth();

    setState(() {
      _testingConnection = false;
      if (health['status'] == 'online') {
        _isSuccess = true;
        final hasKey = health['apiKeyConfigured'] == true;
        final model = health['model'] ?? 'Gemini';
        _testResult = hasKey
            ? '⚡ JARVIS Core Online ($model). All systems green, Sir.'
            : '⚠️ Connected to server, but GEMINI_API_KEY is missing in backend/.env!';
      } else {
        _isSuccess = false;
        _testResult =
            '❌ Unable to connect to backend at ${_urlController.text}.\n'
            'Ensure `npm start` is running in /backend and adb reverse or IP is correct.';
      }
    });

    widget.onSettingsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: JarvisTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: JarvisTheme.cyanDim, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: JarvisTheme.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Row(
            children: [
              Icon(Icons.tune, color: JarvisTheme.cyan, size: 20),
              SizedBox(width: 8),
              Text(
                'CORE CONFIGURATION',
                style: TextStyle(
                  color: JarvisTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Server URL Input
          const Text(
            'Backend Core URL',
            style: TextStyle(
              color: JarvisTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            style: const TextStyle(
              color: JarvisTheme.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: JarvisTheme.background,
              hintText: 'http://127.0.0.1:3000',
              hintStyle: const TextStyle(color: JarvisTheme.textMuted),
              prefixIcon: const Icon(Icons.dns_outlined, color: JarvisTheme.cyan, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: JarvisTheme.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: JarvisTheme.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: JarvisTheme.cyan, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Quick Presets
          Row(
            children: [
              _buildPresetButton('USB (adb reverse)', 'http://127.0.0.1:3000'),
              const SizedBox(width: 8),
              _buildPresetButton('Emulator', 'http://10.0.2.2:3000'),
            ],
          ),
          const SizedBox(height: 14),

          // Test Link Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _testingConnection ? null : _testLink,
              icon: _testingConnection
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(Icons.bolt, color: Colors.black, size: 18),
              label: Text(
                _testingConnection ? 'Testing Neural Link...' : 'Test Server Connection',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: JarvisTheme.emerald,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),

          // Test Result Output
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? JarvisTheme.emerald.withValues(alpha: 0.1)
                    : JarvisTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isSuccess
                      ? JarvisTheme.emerald.withValues(alpha: 0.3)
                      : JarvisTheme.errorRed.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _isSuccess ? JarvisTheme.emerald : JarvisTheme.errorRed,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Text(
            'Tip: When phone is connected via USB, run on PC:\nadb reverse tcp:3000 tcp:3000\nThis enables http://127.0.0.1:3000 on the POCO M7 Plus.',
            style: TextStyle(
              color: JarvisTheme.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(String title, String url) {
    return InkWell(
      onTap: () {
        _urlController.text = url;
        _aiService.setBaseUrl(url);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: JarvisTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: JarvisTheme.surfaceBorder),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: JarvisTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
