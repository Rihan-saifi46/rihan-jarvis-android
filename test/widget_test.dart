import 'package:flutter_test/flutter_test.dart';
import 'package:rihan_jarvis/main.dart';
import 'package:rihan_jarvis/models/chat_message.dart';
import 'package:rihan_jarvis/services/action_service.dart';
import 'package:rihan_jarvis/services/speech_service.dart';

void main() {
  testWidgets('Mickey initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MickeyApp());
    expect(find.text('MICKEY'), findsWidgets);
    expect(find.text('VOICE AI • PHASE 4 ONLINE'), findsOneWidget);
  });

  test('ActionService rejects disallowed actions', () async {
    const invalidAction = ActionData(action: 'send_money');
    final result = await ActionService.execute(invalidAction);
    expect(result.success, false);
    expect(result.message, contains('Security validation'));
  });

  test('ActionService rejects disallowed apps', () async {
    const invalidApp = ActionData(action: 'open_app', app: 'facebook');
    final result = await ActionService.execute(invalidApp);
    expect(result.success, false);
    expect(result.message, contains('not in the allowlist'));
  });

  test('ChatMessage serialization preserves Phase 3 ActionData fields', () {
    const action = ActionData(
      action: 'open_whatsapp',
      phoneNumber: '919876543210',
      message: 'I am on my way',
      isExecuted: true,
      isSuccess: true,
    );
    final msg = ChatMessage(
      id: '123',
      text: 'Opening WhatsApp...',
      sender: MessageSender.jarvis,
      timestamp: DateTime(2026, 1, 1),
      actionData: action,
    );

    final json = msg.toJson();
    expect(json['actionData']['action'], 'open_whatsapp');
    expect(json['actionData']['phoneNumber'], '919876543210');
    expect(json['actionData']['message'], 'I am on my way');
    expect(json['actionData']['isSuccess'], true);

    // Verify deserialization
    final deserialized = ActionData.fromJson(json['actionData'] as Map<String, dynamic>);
    expect(deserialized.action, 'open_whatsapp');
    expect(deserialized.phoneNumber, '919876543210');
    expect(deserialized.message, 'I am on my way');
  });

  test('Phone number sanitization for Calling & SMS', () {
    // Valid numbers
    expect(ActionService.sanitizePhoneNumber('9876543210'), '9876543210');
    expect(ActionService.sanitizePhoneNumber('+91 98765 43210'), '+919876543210');
    expect(ActionService.sanitizePhoneNumber('+1 (415) 555-2671'), '+14155552671');

    // Invalid numbers
    expect(ActionService.sanitizePhoneNumber('123'), null); // too short (< 7)
    expect(ActionService.sanitizePhoneNumber('Call Mom'), null); // letters
    expect(ActionService.sanitizePhoneNumber(''), null);
    expect(ActionService.sanitizePhoneNumber(null), null);
  });

  test('WhatsApp normalization and country code requirement', () {
    // Valid international numbers (11-15 digits)
    expect(ActionService.normalizeWhatsAppNumber('+919876543210'), '919876543210');
    expect(ActionService.normalizeWhatsAppNumber('919876543210'), '919876543210');
    expect(ActionService.normalizeWhatsAppNumber('00919876543210'), '919876543210');
    expect(ActionService.normalizeWhatsAppNumber('+1 (415) 555-2671'), '14155552671');

    // 10 digits without country code returns null (requires country code)
    expect(ActionService.normalizeWhatsAppNumber('9876543210'), null);
    expect(ActionService.normalizeWhatsAppNumber('Sam'), null);
  });

  test('ActionService rejects WhatsApp without country code', () async {
    const action = ActionData(
      action: 'open_whatsapp',
      phoneNumber: '9876543210',
      message: 'Hello',
    );
    final result = await ActionService.execute(action);
    expect(result.success, false);
    expect(result.message, contains('country code'));
  });

  test('ActionService rejects call without valid phone number', () async {
    const action = ActionData(
      action: 'make_call',
      phoneNumber: 'invalid_number',
    );
    final result = await ActionService.execute(action);
    expect(result.success, false);
    expect(result.message, contains('valid phone number'));
  });

  test('ActionService rejects SMS without message text', () async {
    const action = ActionData(
      action: 'send_sms',
      phoneNumber: '9876543210',
      message: '   ',
    );
    final result = await ActionService.execute(action);
    expect(result.success, false);
    expect(result.message, contains('cannot be empty'));
  });

  test('SpeechService.containsWakeWord detects variations of Hey Mickey', () {
    expect(SpeechService.containsWakeWord('Hey Mickey'), true);
    expect(SpeechService.containsWakeWord('hey mickey open youtube'), true);
    expect(SpeechService.containsWakeWord('Mickey call 9876543210'), true);
    expect(SpeechService.containsWakeWord('Hey Micky what is the weather'), true);
    expect(SpeechService.containsWakeWord('Suno Mickey'), true);
    expect(SpeechService.containsWakeWord('Hello Mickey'), true);
    expect(SpeechService.containsWakeWord('Open YouTube'), false);
    expect(SpeechService.containsWakeWord(''), false);
  });

  test('SpeechService.stripWakeWord cleanly extracts command', () {
    expect(SpeechService.stripWakeWord('Hey Mickey, open YouTube'), 'open YouTube');
    expect(SpeechService.stripWakeWord('Hey Mickey: call 9876543210'), 'call 9876543210');
    expect(SpeechService.stripWakeWord('Mickey open YouTube'), 'open YouTube');
    expect(SpeechService.stripWakeWord('Hey Mickey'), '');
    expect(SpeechService.stripWakeWord('Suno Mickey send SMS'), 'send SMS');
  });

  test('ChatMessage supports MessageSender.mickey and isMickey getter', () {
    final msg = ChatMessage(
      id: 'mickey-1',
      text: 'Yes Sir? I\'m listening.',
      sender: MessageSender.mickey,
      timestamp: DateTime.now(),
    );
    expect(msg.isMickey, true);
    expect(msg.isJarvis, true);
    expect(msg.isUser, false);

    final json = msg.toJson();
    expect(json['sender'], 'mickey');
    final restored = ChatMessage.fromJson(json);
    expect(restored.isMickey, true);
  });
}
