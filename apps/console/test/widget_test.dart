import 'package:flutter_test/flutter_test.dart';
import 'package:prepvruksha_console/main.dart';

void main() {
  testWidgets('console placeholder renders', (tester) async {
    await tester.pumpWidget(const ConsoleApp());
    expect(find.text('PrepVruksha Console'), findsOneWidget);
  });
}
