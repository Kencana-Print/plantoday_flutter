import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantoday_flutter/main.dart';

void main() {
  testWidgets('App smoke test loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PlanTodayApp(),
      ),
    );

    // Verifikasi bahwa widget app berhasil dirender
    expect(find.byType(PlanTodayApp), findsOneWidget);
  });
}
