import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flashcard_mobile/main.dart';

void main() {
  testWidgets('App renders without error', (WidgetTester tester) async {
    // 应用能正常构建即视为通过
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
  });
}
