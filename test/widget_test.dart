import 'package:flutter_test/flutter_test.dart';
import 'package:rihan_jarvis/main.dart';

void main() {
  testWidgets('JARVIS initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const JarvisApp());
    expect(find.text('J.A.R.V.I.S.'), findsOneWidget);
  });
}
