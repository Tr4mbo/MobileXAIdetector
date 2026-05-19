enum DetectionLabel { benign, malware }

extension DetectionLabelText on DetectionLabel {
  String get displayName => switch (this) {
    DetectionLabel.benign => 'Benign',
    DetectionLabel.malware => 'Malware',
  };
}

class FeatureImportance {
  const FeatureImportance({required this.feature, required this.importance});

  final String feature;
  final double importance;
}

class ModelMetrics {
  const ModelMetrics({
    required this.accuracy,
    required this.rocAuc,
    required this.recallMalware,
    required this.falsePositiveRate,
    required this.falseNegativeRate,
  });

  final double accuracy;
  final double rocAuc;
  final double recallMalware;
  final double falsePositiveRate;
  final double falseNegativeRate;
}

class ModelMetadata {
  const ModelMetadata({
    required this.modelName,
    required this.featureCount,
    required this.negativeClass,
    required this.positiveClass,
    required this.selectedFeatures,
    required this.globalImportance,
    required this.metrics,
  });

  final String modelName;
  final int featureCount;
  final String negativeClass;
  final String positiveClass;
  final List<String> selectedFeatures;
  final List<FeatureImportance> globalImportance;
  final ModelMetrics metrics;
}

class ScanTarget {
  const ScanTarget({required this.name, required this.sizeBytes, this.path});

  final String name;
  final int sizeBytes;
  final String? path;

  String get sizeLabel {
    if (sizeBytes <= 0) {
      return 'tamano no disponible';
    }
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = sizeBytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${units[unitIndex]}';
  }
}

class LocalFactor {
  const LocalFactor({
    required this.feature,
    required this.impact,
    required this.evidence,
  });

  final String feature;
  final double impact;
  final String evidence;

  bool get increasesRisk => impact >= 0;
}

class ScanResult {
  const ScanResult({
    required this.target,
    required this.label,
    required this.malwareProbability,
    required this.benignProbability,
    required this.localFactors,
    required this.generatedAt,
    required this.isPrototype,
  });

  final ScanTarget target;
  final DetectionLabel label;
  final double malwareProbability;
  final double benignProbability;
  final List<LocalFactor> localFactors;
  final DateTime generatedAt;
  final bool isPrototype;

  double get confidence =>
      label == DetectionLabel.malware ? malwareProbability : benignProbability;
}
