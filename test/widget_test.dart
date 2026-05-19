import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_x_ai_detector/main.dart';

void main() {
  testWidgets('loads detector dashboard', (tester) async {
    await tester.pumpWidget(const MobileXAIDetectorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MXAI Detector'), findsOneWidget);
    expect(find.text('Entrada APK'), findsOneWidget);
    expect(find.text('470'), findsOneWidget);
  });
}
