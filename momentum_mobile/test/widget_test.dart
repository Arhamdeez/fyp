// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:momentum_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('opens main shell without login', (WidgetTester tester) async {
    await tester.pumpWidget(const MomentumApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Momentum'), findsOneWidget);
  });
}
