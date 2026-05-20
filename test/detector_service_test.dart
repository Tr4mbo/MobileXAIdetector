import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_x_ai_detector/models/detector_models.dart';
import 'package:mobile_x_ai_detector/services/detector_service.dart';

void main() {
  const engine = PrototypeDetectionEngine();

  final metadata = ModelMetadata(
    modelName: 'Extra Trees',
    featureCount: 470,
    negativeClass: 'Benign',
    positiveClass: 'Malware',
    selectedFeatures: const [],
    globalImportance: List.generate(
      7,
      (index) => FeatureImportance(
        feature: 'feature_$index',
        importance: 0.02 - (index * 0.001),
      ),
    ),
    metrics: const ModelMetrics(
      accuracy: 0.97,
      rocAuc: 0.99,
      recallMalware: 0.99,
      falsePositiveRate: 0.12,
      falseNegativeRate: 0.01,
    ),
  );

  test(
    'global scan stays benign when only raw permission volume is high',
    () async {
      final result = await engine.analyze(
        metadata: metadata,
        target: const ScanTarget(
          name: 'Analisis global del dispositivo',
          sizeBytes: 475,
          source: ScanSource.observedBehavior,
          packageName: '50 apps de usuario, 1 con senales',
          observedRiskScore: 0.12,
          appCount: 50,
          systemAppCount: 425,
          sensitivePermissionCount: 878,
          highRiskAppCount: 1,
        ),
      );

      expect(result.label, DetectionLabel.benign);
      expect(result.malwareProbability, lessThan(0.5));
    },
  );

  test(
    'global scan requires concentrated high-risk apps to mark malware',
    () async {
      final result = await engine.analyze(
        metadata: metadata,
        target: const ScanTarget(
          name: 'Analisis global del dispositivo',
          sizeBytes: 20,
          source: ScanSource.observedBehavior,
          packageName: '20 apps de usuario, 4 con senales',
          observedRiskScore: 0.9,
          appCount: 20,
          systemAppCount: 30,
          sensitivePermissionCount: 90,
          highRiskAppCount: 4,
        ),
      );

      expect(result.label, DetectionLabel.malware);
      expect(result.malwareProbability, greaterThanOrEqualTo(0.5));
    },
  );
}
