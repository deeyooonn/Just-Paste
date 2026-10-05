import 'package:flutter_test/flutter_test.dart';
import 'package:justpaste/main.dart';

void main() {
  testWidgets('JustPasteApp loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const JustPasteApp());
    expect(find.byType(JustPasteApp), findsOneWidget);
  });
}
