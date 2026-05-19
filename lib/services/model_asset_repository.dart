import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

import '../models/detector_models.dart';

class ModelAssetRepository {
  static const _basePath = 'Android_Malwaredetector';

  Future<ModelMetadata> load() async {
    final config =
        jsonDecode(
              await rootBundle.loadString('$_basePath/training_config.json'),
            )
            as Map<String, dynamic>;
    final metricsJson =
        jsonDecode(
              await rootBundle.loadString('$_basePath/best_model_metrics.json'),
            )
            as Map<String, dynamic>;
    final features =
        (jsonDecode(
                  await rootBundle.loadString(
                    '$_basePath/selected_features.json',
                  ),
                )
                as List<dynamic>)
            .cast<String>();
    final importanceCsv = await rootBundle.loadString(
      '$_basePath/feature_importance.csv',
    );

    return ModelMetadata(
      modelName: _prettyModelName(config['best_model'] as String?),
      featureCount:
          (config['feature_count'] as num?)?.toInt() ?? features.length,
      negativeClass: config['negative_class'] as String? ?? 'Benign',
      positiveClass: config['positive_class'] as String? ?? 'Malware',
      selectedFeatures: features,
      globalImportance: _parseFeatureImportance(importanceCsv),
      metrics: _parseMetrics(metricsJson),
    );
  }

  String _prettyModelName(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Extra Trees';
    }
    return raw
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  List<FeatureImportance> _parseFeatureImportance(String source) {
    final rows = const CsvDecoder(dynamicTyping: true).convert(source);
    return rows
        .skip(1)
        .where((row) => row.length >= 2)
        .map(
          (row) => FeatureImportance(
            feature: row[0].toString(),
            importance: (row[1] as num).toDouble(),
          ),
        )
        .toList(growable: false);
  }

  ModelMetrics _parseMetrics(Map<String, dynamic> json) {
    final rates = json['rates'] as Map<String, dynamic>? ?? const {};
    return ModelMetrics(
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
      rocAuc: (json['roc_auc'] as num?)?.toDouble() ?? 0,
      recallMalware: (json['recall_malware'] as num?)?.toDouble() ?? 0,
      falsePositiveRate:
          (rates['false_positive_rate'] as num?)?.toDouble() ?? 0,
      falseNegativeRate:
          (rates['false_negative_rate'] as num?)?.toDouble() ?? 0,
    );
  }
}
