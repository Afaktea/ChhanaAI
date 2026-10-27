// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chhanaai_flutter/main.dart';

void main() {
  testWidgets('shows chat interface and sends a message', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('ChhanaAI'), findsOneWidget);
    expect(find.text('Message ChhanaAI...'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.byType(Image), findsAtLeastNWidgets(2));

    final messageField = find.byType(TextField);
    expect(tester.widget<TextField>(messageField).maxLines, 5);
    await tester.tap(messageField);
    await tester.pump();
    await tester.enterText(messageField, 'Hi there');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Message ChhanaAI...'), findsOneWidget);
    expect(tester.widget<TextField>(messageField).controller!.text, isEmpty);

    await tester.tap(messageField);
    await tester.enterText(messageField, 'Sent with Enter');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Sent with Enter'), findsOneWidget);
    expect(tester.widget<TextField>(messageField).controller!.text, isEmpty);

    await tester.enterText(messageField, 'First line\nSecond line');
    expect(
      tester.widget<TextField>(messageField).controller!.text,
      'First line\nSecond line',
    );
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('First line\nSecond line'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('New Chat'), findsOneWidget);
    expect(find.text('Chat History'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('New Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Hi there'), findsNothing);
    expect(find.text('How can I help you today?'), findsOneWidget);
  });
}
