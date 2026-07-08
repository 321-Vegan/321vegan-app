import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/helpers/time_counter/time_counter.dart';

void main() {
  testWidgets('TimeCounter displays correct difference',
      (WidgetTester tester) async {
    final now = DateTime.now();
    final targetDate = DateTime(
      now.year - 1,
      now.month - 2,
      now.day - 3,
      now.hour - 4,
      now.minute - 5,
      now.second - 6,
    );

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1170, 2532),
        builder: (_, __) => MaterialApp(
          home: Scaffold(
            // FittedBox absorbs the extra width of the test environment's
            // fixed-width font, which is wider than any real device font.
            body: FittedBox(
              child: TimeCounter(targetDate: targetDate),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));
    final expected = ['01', '02', '03', '04', '05'];
    for (final value in expected) {
      expect(find.text(value), findsOneWidget);
    }
  });

  testWidgets('TimeCounter displays zeros if targetDate is null',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(1170, 2532),
        builder: (_, __) => const MaterialApp(
          home: Scaffold(
            body: FittedBox(
              child: TimeCounter(targetDate: null),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Check that all time values are displayed as '00'
    expect(find.text('00'), findsNWidgets(6));

    // Verify that all time labels are present
    expect(find.text('ans'), findsOneWidget);
    expect(find.text('mois'), findsOneWidget);
    expect(find.text('jours'), findsOneWidget);
    expect(find.text('heures'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
    expect(find.text('sec'), findsOneWidget);
  });
}
