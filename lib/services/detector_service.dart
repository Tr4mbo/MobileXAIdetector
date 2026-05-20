import 'dart:math' as math;

import '../models/detector_models.dart';

abstract class DetectionEngine {
  Future<ScanResult> analyze({
    required ScanTarget target,
    required ModelMetadata metadata,
  });
}

class PrototypeDetectionEngine implements DetectionEngine {
  const PrototypeDetectionEngine();

  @override
  Future<ScanResult> analyze({
    required ScanTarget target,
    required ModelMetadata metadata,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));

    final score = _prototypeRiskScore(target);
    final label = score >= 0.5 ? DetectionLabel.malware : DetectionLabel.benign;

    return ScanResult(
      target: target,
      label: label,
      malwareProbability: score,
      benignProbability: 1 - score,
      localFactors: _prototypeLocalFactors(metadata, target, score),
      generatedAt: DateTime.now(),
      isPrototype: true,
    );
  }

  double _prototypeRiskScore(ScanTarget target) {
    if (target.source == ScanSource.observedBehavior) {
      return _globalPrototypeRiskScore(target);
    }

    final name = target.name.toLowerCase();
    final hashPortion = (_stableHash(name) % 1000) / 1000;
    var score = 0.24 + (hashPortion * 0.34);

    final riskyTokens = [
      'bank',
      'sms',
      'spy',
      'trojan',
      'crack',
      'mod',
      'root',
      'payload',
      'risk',
    ];
    for (final token in riskyTokens) {
      if (name.contains(token)) {
        score += 0.07;
      }
    }

    if (target.sizeBytes > 65 * 1024 * 1024) {
      score += 0.05;
    } else if (target.sizeBytes > 0 && target.sizeBytes < 3 * 1024 * 1024) {
      score -= 0.06;
    }

    if (target.source == ScanSource.installedApp) {
      score += name.contains('system') ? -0.04 : 0.03;
    }

    return score.clamp(0.04, 0.96);
  }

  double _globalPrototypeRiskScore(ScanTarget target) {
    final calibratedRisk = target.observedRiskScore;
    if (calibratedRisk == null) {
      return 0.18;
    }

    final highRiskApps = target.highRiskAppCount ?? 0;
    final userApps = target.appCount ?? 0;
    final baseScore = 0.10 + (calibratedRisk.clamp(0.0, 1.0) * 0.36);

    // Global scans need a higher bar than single APK scans. Permission volume
    // alone is noisy on Android, especially with system and preinstalled apps.
    if (highRiskApps >= 3 && userApps >= 8 && calibratedRisk >= 0.86) {
      return (0.52 + ((calibratedRisk - 0.86) * 0.5)).clamp(0.52, 0.68);
    }

    return baseScore.clamp(0.08, 0.48);
  }

  List<LocalFactor> _prototypeLocalFactors(
    ModelMetadata metadata,
    ScanTarget target,
    double score,
  ) {
    final seed = _stableHash('${target.name}:${target.sizeBytes}');
    final topFeatures = metadata.globalImportance.take(7).toList();

    return [
      for (var index = 0; index < topFeatures.length; index++)
        _factorFromImportance(topFeatures[index], seed, index, score),
    ];
  }

  LocalFactor _factorFromImportance(
    FeatureImportance feature,
    int seed,
    int index,
    double score,
  ) {
    final wobble = 0.65 + (((seed >> (index % 16)) & 0xF) / 32);
    final direction = score >= 0.5 ? 1 : -1;
    final alternate = index.isOdd ? -0.55 : 1.0;
    final impact = feature.importance * wobble * direction * alternate;
    final syntheticCount = 1 + ((seed + index * 17) % 8);

    return LocalFactor(
      feature: feature.feature,
      impact: impact,
      evidence: '$syntheticCount eventos estimados',
    );
  }

  int _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return math.max(hash, 1);
  }
}
