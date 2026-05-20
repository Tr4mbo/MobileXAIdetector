import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_x_ai_detector/main.dart';

void main() {
  testWidgets('loads mobile detector dashboard', (tester) async {
    await tester.pumpWidget(const MobileXAIDetectorApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MXAI Detector'), findsOneWidget);
    expect(find.text('Analisis global'), findsWidgets);
    expect(find.text('Listo para escanear'), findsWidgets);
    expect(find.text('Analizar'), findsOneWidget);
    expect(find.text('Generacion XAI'), findsOneWidget);
    expect(find.text('470 cols'), findsOneWidget);
  });
}
