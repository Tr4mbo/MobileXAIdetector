import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models/detector_models.dart';
import 'services/detector_service.dart';
import 'services/model_asset_repository.dart';

void main() {
  runApp(const MobileXAIDetectorApp());
}

class MobileXAIDetectorApp extends StatelessWidget {
  const MobileXAIDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MXAI Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.voidBlack,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: AppColors.cyan,
          primary: AppColors.cyan,
          secondary: AppColors.lime,
          surface: AppColors.panel,
          error: AppColors.danger,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w800, height: 1.0),
          headlineMedium: TextStyle(fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(height: 1.35),
        ),
      ),
      home: const DetectorScreen(),
    );
  }
}

class DetectorScreen extends StatefulWidget {
  const DetectorScreen({super.key});

  @override
  State<DetectorScreen> createState() => _DetectorScreenState();
}

class _DetectorScreenState extends State<DetectorScreen> {
  final _repository = ModelAssetRepository();
  final _engine = const PrototypeDetectionEngine();

  late final Future<ModelMetadata> _metadataFuture = _repository.load();
  ScanTarget? _target;
  ScanResult? _result;
  bool _isScanning = false;
  String? _error;

  Future<void> _pickApk() async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['apk'],
      withData: false,
    );

    if (selection == null || selection.files.isEmpty) {
      return;
    }

    final file = selection.files.single;
    setState(() {
      _target = ScanTarget(
        name: file.name,
        sizeBytes: file.size,
        path: file.path,
      );
      _result = null;
      _error = null;
    });
  }

  Future<void> _runAnalysis(ModelMetadata metadata) async {
    final target = _target;
    if (target == null || _isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final result = await _engine.analyze(target: target, metadata: metadata);
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo analizar el archivo: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<ModelMetadata>(
        future: _metadataFuture,
        builder: (context, snapshot) {
          return Stack(
            children: [
              const Positioned.fill(child: FuturisticBackground()),
              SafeArea(
                child: snapshot.hasData
                    ? _LoadedDetectorView(
                        metadata: snapshot.data!,
                        target: _target,
                        result: _result,
                        error: _error,
                        isScanning: _isScanning,
                        onPickApk: _pickApk,
                        onAnalyze: () => _runAnalysis(snapshot.data!),
                      )
                    : const _LoadingView(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LoadedDetectorView extends StatelessWidget {
  const _LoadedDetectorView({
    required this.metadata,
    required this.target,
    required this.result,
    required this.error,
    required this.isScanning,
    required this.onPickApk,
    required this.onAnalyze,
  });

  final ModelMetadata metadata;
  final ScanTarget? target;
  final ScanResult? result;
  final String? error;
  final bool isScanning;
  final VoidCallback onPickApk;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final horizontalPadding = constraints.maxWidth >= 700 ? 28.0 : 16.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 18),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: AnalysisPanel(
                        metadata: metadata,
                        target: target,
                        error: error,
                        isScanning: isScanning,
                        onPickApk: onPickApk,
                        onAnalyze: onAnalyze,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: PredictionPanel(
                        result: result,
                        isScanning: isScanning,
                      ),
                    ),
                  ],
                )
              else ...[
                AnalysisPanel(
                  metadata: metadata,
                  target: target,
                  error: error,
                  isScanning: isScanning,
                  onPickApk: onPickApk,
                  onAnalyze: onAnalyze,
                ),
                const SizedBox(height: 14),
                PredictionPanel(result: result, isScanning: isScanning),
              ],
              const SizedBox(height: 14),
              PipelinePanel(
                target: target,
                result: result,
                isScanning: isScanning,
              ),
              const SizedBox(height: 14),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ExplanationPanel(result: result)),
                    const SizedBox(width: 16),
                    Expanded(child: ModelPanel(metadata: metadata)),
                  ],
                )
              else ...[
                ExplanationPanel(result: result),
                const SizedBox(height: 14),
                ModelPanel(metadata: metadata),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.7)),
            color: AppColors.cyan.withValues(alpha: 0.11),
          ),
          child: const Icon(Icons.security_rounded, color: AppColors.cyan),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MXAI Detector', style: textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Android malware analysis console',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const _StatusBeacon(),
      ],
    );
  }
}

class _StatusBeacon extends StatelessWidget {
  const _StatusBeacon();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Metadata del modelo cargada',
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.lime.withValues(alpha: 0.7)),
          color: AppColors.lime.withValues(alpha: 0.09),
        ),
        child: const Icon(Icons.check_rounded, color: AppColors.lime, size: 22),
      ),
    );
  }
}

class AnalysisPanel extends StatelessWidget {
  const AnalysisPanel({
    super.key,
    required this.metadata,
    required this.target,
    required this.error,
    required this.isScanning,
    required this.onPickApk,
    required this.onAnalyze,
  });

  final ModelMetadata metadata;
  final ScanTarget? target;
  final String? error;
  final bool isScanning;
  final VoidCallback onPickApk;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(icon: Icons.android_rounded, title: 'Entrada APK'),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.line),
              color: AppColors.ink.withValues(alpha: 0.52),
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.cyan.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.cyan.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: AppColors.cyan,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target?.name ?? 'Sin APK seleccionado',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        target?.sizeLabel ??
                            '${metadata.featureCount} columnas esperadas',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: isScanning ? null : onPickApk,
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Seleccionar APK'),
              ),
              OutlinedButton.icon(
                onPressed: target == null || isScanning ? null : onAnalyze,
                icon: isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar_rounded),
                label: Text(isScanning ? 'Analizando' : 'Analizar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _MetricStrip(metadata: metadata),
        ],
      ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metadata});

  final ModelMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Modelo', metadata.modelName),
      ('Features', '${metadata.featureCount}'),
      ('ROC AUC', _percent(metadata.metrics.rocAuc)),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _MetricTile(label: items[i].$1, value: items[i].$2),
          ),
          if (i < items.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.ink.withValues(alpha: 0.48),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.cyan,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PredictionPanel extends StatelessWidget {
  const PredictionPanel({
    super.key,
    required this.result,
    required this.isScanning,
  });

  final ScanResult? result;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final current = result;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(icon: Icons.bolt_rounded, title: 'Prediccion'),
          const SizedBox(height: 18),
          if (isScanning)
            const _ScanInProgress()
          else if (current == null)
            const _EmptyPrediction()
          else
            _PredictionResult(result: current),
        ],
      ),
    );
  }
}

class _ScanInProgress extends StatelessWidget {
  const _ScanInProgress();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 286,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Generando vector',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Extractor compatible en preparacion',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyPrediction extends StatelessWidget {
  const _EmptyPrediction();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 286,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radar_rounded,
            color: AppColors.cyan.withValues(alpha: 0.65),
            size: 74,
          ),
          const SizedBox(height: 14),
          Text(
            'Esperando muestra',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Resultado Benign/Malware',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PredictionResult extends StatelessWidget {
  const _PredictionResult({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final isMalware = result.label == DetectionLabel.malware;
    final accent = isMalware ? AppColors.danger : AppColors.lime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: RiskGauge(
            value: result.malwareProbability,
            label: result.label.displayName,
            accent: accent,
          ),
        ),
        const SizedBox(height: 20),
        _ProbabilityBars(result: result),
        const SizedBox(height: 18),
        Row(
          children: [
            Icon(Icons.verified_rounded, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Confianza ${_percent(result.confidence)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        if (result.isPrototype) ...[
          const SizedBox(height: 12),
          Text(
            'Modo prototipo: falta conectar extractor real y backend del joblib.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.amber),
          ),
        ],
      ],
    );
  }
}

class _ProbabilityBars extends StatelessWidget {
  const _ProbabilityBars({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProbabilityBar(
          label: 'Malware',
          value: result.malwareProbability,
          color: AppColors.danger,
        ),
        const SizedBox(height: 10),
        _ProbabilityBar(
          label: 'Benign',
          value: result.benignProbability,
          color: AppColors.lime,
        ),
      ],
    );
  }
}

class _ProbabilityBar extends StatelessWidget {
  const _ProbabilityBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(_percent(value)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 9,
            backgroundColor: AppColors.ink,
            color: color,
          ),
        ),
      ],
    );
  }
}

class PipelinePanel extends StatelessWidget {
  const PipelinePanel({
    super.key,
    required this.target,
    required this.result,
    required this.isScanning,
  });

  final ScanTarget? target;
  final ScanResult? result;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final nodes = [
      _PipelineNode(
        icon: Icons.android_rounded,
        label: 'APK',
        state: target != null ? PipelineState.ready : PipelineState.pending,
      ),
      _PipelineNode(
        icon: Icons.schema_rounded,
        label: 'Extractor',
        state: result != null || isScanning
            ? PipelineState.prototype
            : PipelineState.pending,
      ),
      _PipelineNode(
        icon: Icons.grid_on_rounded,
        label: '470 columnas',
        state: result != null ? PipelineState.prototype : PipelineState.pending,
      ),
      _PipelineNode(
        icon: Icons.memory_rounded,
        label: 'Joblib',
        state: result != null ? PipelineState.blocked : PipelineState.pending,
      ),
      _PipelineNode(
        icon: Icons.analytics_rounded,
        label: 'SHAP',
        state: result != null ? PipelineState.blocked : PipelineState.pending,
      ),
      _PipelineNode(
        icon: Icons.psychology_alt_rounded,
        label: 'Ollama',
        state: result != null ? PipelineState.blocked : PipelineState.pending,
      ),
    ];

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(
            icon: Icons.account_tree_rounded,
            title: 'Cadena ML',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              if (!wide) {
                return Column(
                  children: [
                    for (var i = 0; i < nodes.length; i++) ...[
                      nodes[i],
                      if (i < nodes.length - 1)
                        const SizedBox(height: 10, child: _VerticalConnector()),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < nodes.length; i++) ...[
                    Expanded(child: nodes[i]),
                    if (i < nodes.length - 1)
                      const SizedBox(width: 22, child: _HorizontalConnector()),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

enum PipelineState { ready, prototype, blocked, pending }

class _PipelineNode extends StatelessWidget {
  const _PipelineNode({
    required this.icon,
    required this.label,
    required this.state,
  });

  final IconData icon;
  final String label;
  final PipelineState state;

  @override
  Widget build(BuildContext context) {
    final (color, statusIcon, tooltip) = switch (state) {
      PipelineState.ready => (AppColors.lime, Icons.check_rounded, 'Activo'),
      PipelineState.prototype => (
        AppColors.amber,
        Icons.construction_rounded,
        'Prototipo',
      ),
      PipelineState.blocked => (
        AppColors.danger,
        Icons.link_off_rounded,
        'Pendiente de conexion',
      ),
      PipelineState.pending => (
        AppColors.muted,
        Icons.more_horiz_rounded,
        'En espera',
      ),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
        constraints: const BoxConstraints(minHeight: 94),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          color: AppColors.ink.withValues(alpha: 0.44),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Icon(statusIcon, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class ExplanationPanel extends StatelessWidget {
  const ExplanationPanel({super.key, required this.result});

  final ScanResult? result;

  @override
  Widget build(BuildContext context) {
    final current = result;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(
            icon: Icons.insights_rounded,
            title: 'Explicabilidad',
          ),
          const SizedBox(height: 16),
          if (current == null)
            _MutedLine(
              icon: Icons.pending_rounded,
              text: 'SHAP local y explicacion Ollama quedan en espera.',
            )
          else ...[
            for (final factor in current.localFactors)
              _FactorRow(factor: factor),
            const SizedBox(height: 14),
            _MutedLine(
              icon: Icons.psychology_alt_rounded,
              text:
                  'Ollama recibira prediccion, probabilidades y factores locales.',
            ),
          ],
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final LocalFactor factor;

  @override
  Widget build(BuildContext context) {
    final color = factor.increasesRisk ? AppColors.danger : AppColors.lime;
    final normalized = (factor.impact.abs() / 0.03).clamp(0.08, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            factor.increasesRisk
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.feature,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: normalized,
                    minHeight: 6,
                    color: color,
                    backgroundColor: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              factor.evidence,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class ModelPanel extends StatelessWidget {
  const ModelPanel({super.key, required this.metadata});

  final ModelMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelTitle(icon: Icons.dataset_rounded, title: 'Modelo'),
          const SizedBox(height: 16),
          _ModelStatLine(
            label: 'Archivo',
            value: 'android_malware_detector.joblib',
          ),
          _ModelStatLine(
            label: 'Clases',
            value: '${metadata.negativeClass} / ${metadata.positiveClass}',
          ),
          _ModelStatLine(
            label: 'Accuracy',
            value: _percent(metadata.metrics.accuracy),
          ),
          _ModelStatLine(
            label: 'Recall malware',
            value: _percent(metadata.metrics.recallMalware),
          ),
          const SizedBox(height: 16),
          Text(
            'Importancia global',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.cyan,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in metadata.globalImportance.take(5))
            _GlobalImportanceRow(item: item),
        ],
      ),
    );
  }
}

class _ModelStatLine extends StatelessWidget {
  const _ModelStatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalImportanceRow extends StatelessWidget {
  const _GlobalImportanceRow({required this.item});

  final FeatureImportance item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.feature,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 94,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: (item.importance / 0.026).clamp(0.02, 1.0),
                backgroundColor: AppColors.ink,
                color: AppColors.cyan,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.amber),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.panel.withValues(alpha: 0.9),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PanelTitle extends StatelessWidget {
  const PanelTitle({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.cyan, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class RiskGauge extends StatelessWidget {
  const RiskGauge({
    super.key,
    required this.value,
    required this.label,
    required this.accent,
  });

  final double value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(210),
            painter: _RiskGaugePainter(value: value, accent: accent),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _percent(value),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskGaugePainter extends CustomPainter {
  const _RiskGaugePainter({required this.value, required this.accent});

  final double value;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = AppColors.ink;
    final valuePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [accent.withValues(alpha: 0.2), accent],
      ).createShader(rect);
    final tickPaint = Paint()
      ..strokeWidth = 1
      ..color = AppColors.cyan.withValues(alpha: 0.34);

    canvas.drawCircle(center, radius, backgroundPaint);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, valuePaint);

    for (var i = 0; i < 40; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / 40);
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 25),
        center.dy + math.sin(angle) * (radius - 25),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 18),
        center.dy + math.sin(angle) * (radius - 18),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.accent != accent;
  }
}

class FuturisticBackground extends StatelessWidget {
  const FuturisticBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.voidBlack, Color(0xFF08161B), Color(0xFF101317)],
        ),
      ),
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.065)
      ..strokeWidth = 1;
    final strongPaint = Paint()
      ..color = AppColors.lime.withValues(alpha: 0.09)
      ..strokeWidth = 1.2;

    const spacing = 42.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final path = Path()
      ..moveTo(size.width * 0.05, size.height * 0.18)
      ..lineTo(size.width * 0.32, size.height * 0.18)
      ..lineTo(size.width * 0.44, size.height * 0.31)
      ..lineTo(size.width * 0.78, size.height * 0.31)
      ..moveTo(size.width * 0.58, size.height * 0.08)
      ..lineTo(size.width * 0.82, size.height * 0.08)
      ..lineTo(size.width * 0.93, size.height * 0.2);
    canvas.drawPath(path, strongPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorizontalConnector extends StatelessWidget {
  const _HorizontalConnector();

  @override
  Widget build(BuildContext context) {
    return Center(child: Container(height: 1, color: AppColors.line));
  }
}

class _VerticalConnector extends StatelessWidget {
  const _VerticalConnector();

  @override
  Widget build(BuildContext context) {
    return Center(child: Container(width: 1, color: AppColors.line));
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class AppColors {
  const AppColors._();

  static const voidBlack = Color(0xFF05080C);
  static const panel = Color(0xFF101820);
  static const ink = Color(0xFF17232D);
  static const line = Color(0xFF263D45);
  static const muted = Color(0xFF96A6AA);
  static const cyan = Color(0xFF28D8D1);
  static const lime = Color(0xFFA4F06C);
  static const amber = Color(0xFFF2C94C);
  static const danger = Color(0xFFFF5570);
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';
