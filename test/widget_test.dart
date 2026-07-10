import 'package:flutter_test/flutter_test.dart';
import 'package:scoreboard/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CricketApp());
    expect(find.text('Cricket Scoreboard'), findsAny);
  });
}
