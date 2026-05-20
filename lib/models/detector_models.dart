enum DetectionLabel { benign, malware }

enum ScanSource { apkFile, installedApp, observedBehavior }

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
  const ScanTarget({
    required this.name,
    required this.sizeBytes,
    this.path,
    this.packageName,
    this.source = ScanSource.apkFile,
    this.observedRiskScore,
    this.appCount,
    this.systemAppCount,
    this.sensitivePermissionCount,
    this.highRiskAppCount,
  });

  final String name;
  final int sizeBytes;
  final String? path;
  final String? packageName;
  final ScanSource source;
  final double? observedRiskScore;
  final int? appCount;
  final int? systemAppCount;
  final int? sensitivePermissionCount;
  final int? highRiskAppCount;

  String get sourceLabel => switch (source) {
    ScanSource.apkFile => 'APK externo',
    ScanSource.installedApp => 'App instalada',
    ScanSource.observedBehavior => 'Analisis global',
  };

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

class InstalledAndroidApp {
  const InstalledAndroidApp({
    required this.packageName,
    required this.label,
    required this.versionName,
    required this.versionCode,
    required this.firstInstallTime,
    required this.lastUpdateTime,
    required this.requestedPermissions,
    required this.isSystemApp,
    this.sourceDir,
  });

  final String packageName;
  final String label;
  final String versionName;
  final int versionCode;
  final int firstInstallTime;
  final int lastUpdateTime;
  final List<String> requestedPermissions;
  final bool isSystemApp;
  final String? sourceDir;

  factory InstalledAndroidApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledAndroidApp(
      packageName: map['packageName'] as String? ?? '',
      label: map['label'] as String? ?? map['packageName'] as String? ?? 'App',
      versionName: map['versionName'] as String? ?? 'unknown',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      firstInstallTime: (map['firstInstallTime'] as num?)?.toInt() ?? 0,
      lastUpdateTime: (map['lastUpdateTime'] as num?)?.toInt() ?? 0,
      requestedPermissions:
          (map['requestedPermissions'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false),
      isSystemApp: map['isSystemApp'] as bool? ?? false,
      sourceDir: map['sourceDir'] as String?,
    );
  }

  ScanTarget toScanTarget() {
    return ScanTarget(
      name: label,
      sizeBytes: 0,
      path: sourceDir,
      packageName: packageName,
      source: ScanSource.installedApp,
    );
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
