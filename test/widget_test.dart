import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nutriguard1/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://tlcsqlemhpxftatpivac.supabase.co',
      publishableKey: 'sb_publishable_RkyrNG8clRlnHWJFvmOEPQ_DIRp4SKV',
    );
  });

  testWidgets('NutriGuardApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NutriGuardApp());
    expect(find.byType(MaterialApp), findsOneWidget);

    // Drain timers from splash animation
    await tester.pump(const Duration(seconds: 5));
  });
}
