import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_message.dart';

class ActionResult {
  final bool success;
  final String message;

  const ActionResult({
    required this.success,
    required this.message,
  });
}

class ActionService {
  static const MethodChannel _channel =
      MethodChannel('com.example.rihan_jarvis/app_control');

  /// Strict allowlisted applications
  static const Set<String> allowedApps = {
    'chrome',
    'youtube',
    'maps',
    'settings',
  };

  /// Strict allowlisted actions
  static const Set<String> allowedActions = {
    'google_search',
    'youtube_search',
    'open_app',
  };

  /// Validates and executes an Android action from JARVIS
  static Future<ActionResult> execute(ActionData actionData) async {
    final action = actionData.action.toLowerCase().trim();

    if (!allowedActions.contains(action)) {
      if (kDebugMode) debugPrint('Security validation: Action "$action" rejected.');
      return ActionResult(
        success: false,
        message: 'Security validation: Action "$action" is not in the allowed list.',
      );
    }

    switch (action) {
      case 'google_search':
        return _executeGoogleSearch(actionData.query);
      case 'youtube_search':
        return _executeYoutubeSearch(actionData.query);
      case 'open_app':
        return _executeOpenApp(actionData.app);
      default:
        return const ActionResult(
          success: false,
          message: 'Unknown action command, Sir.',
        );
    }
  }

  static Future<ActionResult> _executeGoogleSearch(String? query) async {
    final cleanQuery = query?.trim() ?? '';
    if (cleanQuery.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'Search query cannot be empty, Sir.',
      );
    }

    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final uri = Uri.parse('https://www.google.com/search?q=$encoded');

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return ActionResult(
          success: true,
          message: 'Google search opened for "$cleanQuery"',
        );
      } else {
        return const ActionResult(
          success: false,
          message: 'Unable to launch Google search browser, Sir.',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Google search error: $e');
      return ActionResult(
        success: false,
        message: 'Failed to execute Google search: $e',
      );
    }
  }

  static Future<ActionResult> _executeYoutubeSearch(String? query) async {
    final cleanQuery = query?.trim() ?? '';
    if (cleanQuery.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'YouTube search query cannot be empty, Sir.',
      );
    }

    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final uri = Uri.parse('https://www.youtube.com/results?search_query=$encoded');

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        return ActionResult(
          success: true,
          message: 'YouTube search opened for "$cleanQuery"',
        );
      } else {
        return const ActionResult(
          success: false,
          message: 'Unable to open YouTube search, Sir.',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('YouTube search error: $e');
      return ActionResult(
        success: false,
        message: 'Failed to execute YouTube search: $e',
      );
    }
  }

  static Future<ActionResult> _executeOpenApp(String? app) async {
    final cleanApp = (app ?? '').toLowerCase().trim();

    // Map common variants to canonical names
    final canonicalApp = cleanApp == 'google_maps' || cleanApp == 'google maps'
        ? 'maps'
        : (cleanApp == 'google chrome' ? 'chrome' : cleanApp);

    if (!allowedApps.contains(canonicalApp)) {
      return ActionResult(
        success: false,
        message: 'App "$canonicalApp" is not in the allowlist. Supported: Chrome, YouTube, Maps, Settings.',
      );
    }

    try {
      final bool? success = await _channel.invokeMethod<bool>(
        'openApp',
        {'app': canonicalApp},
      );

      if (success == true) {
        return ActionResult(
          success: true,
          message: 'Opened ${canonicalApp.toUpperCase()} successfully, Sir.',
        );
      } else {
        return ActionResult(
          success: false,
          message: 'Could not open $canonicalApp.',
        );
      }
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('PlatformException opening $canonicalApp: ${e.message}');

      // Web fallback for YouTube, Chrome, Maps if app package not found
      if (e.code == 'APP_NOT_INSTALLED') {
        if (canonicalApp == 'youtube') {
          await launchUrl(
            Uri.parse('https://www.youtube.com'),
            mode: LaunchMode.externalApplication,
          );
          return const ActionResult(
            success: true,
            message: 'Opened YouTube in browser, Sir.',
          );
        } else if (canonicalApp == 'chrome') {
          await launchUrl(
            Uri.parse('https://www.google.com'),
            mode: LaunchMode.externalApplication,
          );
          return const ActionResult(
            success: true,
            message: 'Opened browser fallback for Chrome, Sir.',
          );
        } else if (canonicalApp == 'maps') {
          await launchUrl(
            Uri.parse('https://maps.google.com'),
            mode: LaunchMode.externalApplication,
          );
          return const ActionResult(
            success: true,
            message: 'Opened Google Maps in browser, Sir.',
          );
        }

        return ActionResult(
          success: false,
          message: '$canonicalApp is not installed on this device, Sir.',
        );
      }

      return ActionResult(
        success: false,
        message: 'Failed to launch $canonicalApp: ${e.message}',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Unexpected error opening $canonicalApp: $e');
      return ActionResult(
        success: false,
        message: 'Error launching $canonicalApp: $e',
      );
    }
  }
}
