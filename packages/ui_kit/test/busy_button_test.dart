import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('BusyButton shows a spinner and ignores taps while busy', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: BusyButton(label: 'Go', busy: true, onPressed: () => taps++),
      ),
    );
    expect(find.text('Go'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
  });
}
