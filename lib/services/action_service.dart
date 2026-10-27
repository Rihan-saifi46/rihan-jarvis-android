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
    'make_call',
    'send_sms',
    'open_whatsapp',
  };

  /// Starts the native Android Mickey foreground listening service
  static Future<bool> startMickeyService() async {
    try {
      final res = await _channel.invokeMethod<bool>('startMickeyService');
      return res ?? false;
    } catch (e) {
      debugPrint('[ActionService] startMickeyService error: $e');
      return false;
    }
  }

  /// Stops the native Android Mickey foreground listening service
  static Future<bool> stopMickeyService() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopMickeyService');
      return res ?? false;
    } catch (e) {
      debugPrint('[ActionService] stopMickeyService error: $e');
      return false;
    }
  }

  /// Checks if the native Android Mickey foreground listening service is active
  static Future<bool> isMickeyServiceRunning() async {
    try {
      final res = await _channel.invokeMethod<bool>('isMickeyServiceRunning');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Validates and executes an Android action from Mickey
  static Future<ActionResult> execute(ActionData actionData) async {
    final action = actionData.action.toLowerCase().trim();
    debugPrint('[ActionService] Executing action: "$action" (app=${actionData.app}, phone=${actionData.phoneNumber}, query=${actionData.query})');

    if (!allowedActions.contains(action)) {
      debugPrint('[ActionService] Security validation FAILED: Action "$action" rejected.');
      return ActionResult(
        success: false,
        message: 'Security validation: Action "$action" is not in the allowed list.',
      );
    }

    ActionResult result;
    switch (action) {
      case 'google_search':
        result = await _executeGoogleSearch(actionData.query);
        break;
      case 'youtube_search':
        result = await _executeYoutubeSearch(actionData.query);
        break;
      case 'open_app':
        result = await _executeOpenApp(actionData.app);
        break;
      case 'make_call':
        result = await _executeMakeCall(actionData.phoneNumber);
        break;
      case 'send_sms':
        result = await _executeSendSms(actionData.phoneNumber, actionData.message);
        break;
      case 'open_whatsapp':
        result = await _executeOpenWhatsApp(actionData.phoneNumber, actionData.message);
        break;
      default:
        result = const ActionResult(
          success: false,
          message: 'Unknown action command, Sir.',
        );
        break;
    }

    debugPrint('[ActionService] Execution completed: success=${result.success}, message="${result.message}"');
    return result;
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
      debugPrint('[ActionService] Launching Google Search: $uri');

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
      debugPrint('[ActionService] Google search error: $e');
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
      debugPrint('[ActionService] Launching YouTube Search: $uri');

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
      debugPrint('[ActionService] YouTube search error: $e');
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
      debugPrint('[ActionService] Invoking MethodChannel openApp: $canonicalApp');
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
      debugPrint('[ActionService] PlatformException opening $canonicalApp: ${e.code} - ${e.message}');

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
      debugPrint('[ActionService] Unexpected error opening $canonicalApp: $e');
      return ActionResult(
        success: false,
        message: 'Error launching $canonicalApp: $e',
      );
    }
  }

  /// Sanitizes phone numbers for Android Dialer and SMS.
  /// Removes spaces, dashes, parentheses.
  /// Enforces valid E.164 phone format: optional leading '+', followed by 7 to 15 digits.
  static String? sanitizePhoneNumber(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '').trim();
    if (RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned)) {
      return cleaned;
    }
    return null;
  }

  /// Normalizes phone numbers for WhatsApp wa.me links.
  /// WhatsApp requires international format with digits only (no '+', no '00', no symbols).
  /// Requires between 11 and 15 digits (verifying country code is included).
  static String? normalizeWhatsAppNumber(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.replaceAll(RegExp(r'[\s\-()]'), '').trim();
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    } else if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    if (RegExp(r'^[0-9]{11,15}$').hasMatch(cleaned)) {
      return cleaned;
    }
    return null;
  }

  static Future<ActionResult> _executeMakeCall(String? rawNumber) async {
    final cleanNumber = sanitizePhoneNumber(rawNumber);
    if (cleanNumber == null || cleanNumber.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'Please provide a valid phone number to call, Sir.',
      );
    }

    try {
      debugPrint('[ActionService] Invoking MethodChannel makeCall: $cleanNumber');
      final bool? success = await _channel.invokeMethod<bool>(
        'makeCall',
        {'phoneNumber': cleanNumber},
      );

      if (success == true) {
        return ActionResult(
          success: true,
          message: 'Opening dialer for $cleanNumber, Sir.',
        );
      }
    } catch (e) {
      debugPrint('[ActionService] Native makeCall failed, attempting url_launcher fallback: $e');
    }

    // Direct url_launcher fallback with tel: URI using externalApplication mode
    try {
      final uri = Uri.parse('tel:$cleanNumber');
      debugPrint('[ActionService] Launching tel URI: $uri');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        return ActionResult(
          success: true,
          message: 'Opening dialer for $cleanNumber, Sir.',
        );
      }
    } catch (e) {
      debugPrint('[ActionService] url_launcher tel error: $e');
    }

    return ActionResult(
      success: false,
      message: 'Unable to open phone dialer for $cleanNumber, Sir.',
    );
  }

  static Future<ActionResult> _executeSendSms(String? rawNumber, String? rawMessage) async {
    final cleanNumber = sanitizePhoneNumber(rawNumber);
    if (cleanNumber == null || cleanNumber.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'Please provide a valid phone number for SMS, Sir.',
      );
    }

    final cleanMessage = (rawMessage ?? '').trim();
    if (cleanMessage.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'SMS message text cannot be empty, Sir.',
      );
    }

    try {
      debugPrint('[ActionService] Invoking MethodChannel sendSms: to=$cleanNumber, msg="$cleanMessage"');
      final bool? success = await _channel.invokeMethod<bool>(
        'sendSms',
        {'phoneNumber': cleanNumber, 'message': cleanMessage},
      );

      if (success == true) {
        return ActionResult(
          success: true,
          message: 'Opening SMS app for $cleanNumber, Sir.',
        );
      }
    } catch (e) {
      debugPrint('[ActionService] Native sendSms failed, attempting url_launcher fallback: $e');
    }

    // Direct url_launcher fallback with sms: URI
    try {
      final encodedBody = Uri.encodeComponent(cleanMessage);
      final uri = Uri.parse('sms:$cleanNumber?body=$encodedBody');
      debugPrint('[ActionService] Launching sms URI: $uri');
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) {
        return ActionResult(
          success: true,
          message: 'Opening SMS app for $cleanNumber, Sir.',
        );
      }
    } catch (e) {
      debugPrint('[ActionService] url_launcher sms error: $e');
    }

    return ActionResult(
      success: false,
      message: 'Unable to open SMS application, Sir.',
    );
  }

  static Future<ActionResult> _executeOpenWhatsApp(String? rawNumber, String? rawMessage) async {
    final rawCleaned = (rawNumber ?? '').replaceAll(RegExp(r'[\s\-()]'), '').trim();

    // Check if country code was omitted (e.g. 10 digits domestic number)
    if (rawCleaned.length == 10 && !rawCleaned.startsWith('+')) {
      return const ActionResult(
        success: false,
        message: 'WhatsApp requires an international country code (e.g. +91 9876543210). Please specify the country code, Sir.',
      );
    }

    final normalizedNumber = normalizeWhatsAppNumber(rawNumber);
    if (normalizedNumber == null) {
      return const ActionResult(
        success: false,
        message: 'Please provide a valid international phone number for WhatsApp, Sir.',
      );
    }

    final cleanMessage = (rawMessage ?? '').trim();
    if (cleanMessage.isEmpty) {
      return const ActionResult(
        success: false,
        message: 'WhatsApp message text cannot be empty, Sir.',
      );
    }

    try {
      debugPrint('[ActionService] Invoking MethodChannel openWhatsApp: to=+$normalizedNumber, msg="$cleanMessage"');
      final bool? success = await _channel.invokeMethod<bool>(
        'openWhatsApp',
        {'phoneNumber': normalizedNumber, 'message': cleanMessage},
      );

      if (success == true) {
        return ActionResult(
          success: true,
          message: 'Opening WhatsApp conversation for +$normalizedNumber, Sir.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[ActionService] PlatformException opening WhatsApp: ${e.code} - ${e.message}');

      // If WhatsApp app is not installed, open supported wa.me web link in browser
      if (e.code == 'APP_NOT_INSTALLED') {
        try {
          final webUri = Uri.parse(
            'https://wa.me/$normalizedNumber?text=${Uri.encodeComponent(cleanMessage)}',
          );
          debugPrint('[ActionService] Opening WhatsApp fallback web link: $webUri');
          final launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
          if (launched) {
            return ActionResult(
              success: true,
              message: 'WhatsApp app not found; opened conversation in browser for +$normalizedNumber, Sir.',
            );
          }
        } catch (err) {
          debugPrint('[ActionService] WhatsApp web fallback error: $err');
        }

        return const ActionResult(
          success: false,
          message: 'WhatsApp is not installed and browser link could not be opened, Sir.',
        );
      }
    } catch (e) {
      debugPrint('[ActionService] Unexpected error opening WhatsApp: $e');
    }

    // Direct deep link fallback
    try {
      final webUri = Uri.parse(
        'https://wa.me/$normalizedNumber?text=${Uri.encodeComponent(cleanMessage)}',
      );
      debugPrint('[ActionService] Attempting direct deep link launch: $webUri');
      final launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (launched) {
        return ActionResult(
          success: true,
          message: 'Opening WhatsApp conversation for +$normalizedNumber, Sir.',
        );
      }
    } catch (e) {
      debugPrint('[ActionService] Direct deep link error: $e');
    }

    return ActionResult(
      success: false,
      message: 'Unable to open WhatsApp for +$normalizedNumber, Sir.',
    );
  }
}
