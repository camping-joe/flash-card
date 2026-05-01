import 'package:flutter_test/flutter_test.dart';
import 'package:flashcard_mobile/main.dart';

void main() {
  testWidgets('App builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  });
}
