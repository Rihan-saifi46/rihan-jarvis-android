import 'package:flutter_test/flutter_test.dart';
import 'package:rihan_jarvis/main.dart';
import 'package:rihan_jarvis/models/chat_message.dart';
import 'package:rihan_jarvis/services/action_service.dart';

void main() {
  testWidgets('JARVIS initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    expect(find.text('J.A.R.V.I.S.'), findsOneWidget);
  });

  test('ActionService rejects disallowed actions', () async {
    const invalidAction = ActionData(action: 'send_whatsapp');
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

  test('ChatMessage serialization preserves ActionData', () {
    const action = ActionData(
      action: 'youtube_search',
      query: 'latest songs',
      isExecuted: true,
      isSuccess: true,
    );
    final msg = ChatMessage(
      id: '123',
      text: 'Searching YouTube...',
      sender: MessageSender.jarvis,
      timestamp: DateTime(2026, 1, 1),
      actionData: action,
    );

    final json = msg.toJson();
    expect(json['actionData']['action'], 'youtube_search');
    expect(json['actionData']['query'], 'latest songs');
    expect(json['actionData']['isSuccess'], true);
  });
}
