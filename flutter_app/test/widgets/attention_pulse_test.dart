import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegan_app/widgets/shared/attention_pulse.dart';

void main() {
  testWidgets('removed without ever being enabled, it does not throw',
      (tester) async {
    await tester.pumpWidget(const AttentionPulse(
      enabled: false,
      radius: 8,
      color: Colors.green,
      child: SizedBox(width: 10, height: 10),
    ));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
