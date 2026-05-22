import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/detector_models.dart';
import 'services/android_app_scanner_service.dart';
import 'services/detector_service.dart';
import 'services/model_asset_repository.dart';
import 'services/ollama_service.dart';

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
          headlineMedium: TextStyle(fontWeight: FontWeight.w900),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w800),
          bodyMedium: TextStyle(height: 1.35),
        ),
      ),
      home: const DetectorScreen(),
    );
  }
}

enum AppSection { scanner, decision, data, xai, services }

class DetectorScreen extends StatefulWidget {
  const DetectorScreen({super.key});

  @override
  State<DetectorScreen> createState() => _DetectorScreenState();
}

class _DetectorScreenState extends State<DetectorScreen> {
  final _repository = ModelAssetRepository();
  final _engine = const PrototypeDetectionEngine();
  final _androidScanner = const AndroidAppScannerService();

  late final Future<ModelMetadata> _metadataFuture = _repository.load();
  late final ScanTarget _defaultGlobalTarget = const ScanTarget(
    name: 'Analisis global del dispositivo',
    sizeBytes: 0,
    source: ScanSource.observedBehavior,
  );

  StreamSubscription<ScanTarget>? _externalApkSubscription;
  ScanTarget? _globalTarget;
  ScanResult? _globalResult;
  ScanTarget? _externalApkTarget;
  ScanResult? _externalApkResult;
  List<InstalledAndroidApp> _installedApps = const [];
  AppSection _section = AppSection.scanner;
  bool _isGlobalScanning = false;
  bool _isExternalScanning = false;
  bool _isNavOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _globalTarget = _defaultGlobalTarget;
    _bootstrapExternalApkHandler();
  }

  @override
  void dispose() {
    _externalApkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapExternalApkHandler() async {
    await _androidScanner.initializeExternalApkListener();
    _externalApkSubscription = _androidScanner.externalApkStream.listen(
      _handleExternalApk,
    );

    final initialApk = await _androidScanner.getInitialExternalApk();
    if (initialApk != null && mounted) {
      await _handleExternalApk(initialApk);
    }
  }

  Future<void> _handleExternalApk(ScanTarget target) async {
    final metadata = await _metadataFuture;
    if (!mounted) {
      return;
    }

    setState(() {
      _externalApkTarget = target;
      _externalApkResult = null;
      _isExternalScanning = true;
      _error = null;
    });

    try {
      final result = await _engine.analyze(target: target, metadata: metadata);
      if (!mounted) {
        return;
      }
      setState(() {
        _externalApkResult = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo analizar el APK externo: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExternalScanning = false;
        });
      }
    }
  }

  Future<void> _runGlobalAnalysis(ModelMetadata metadata) async {
    if (_isGlobalScanning) {
      return;
    }

    setState(() {
      _isGlobalScanning = true;
      _error = null;
      _section = AppSection.scanner;
      _isNavOpen = false;
    });

    try {
      final apps = await _androidScanner.listInstalledApps();
      final target = _buildGlobalTarget(apps);
      final result = await _engine.analyze(target: target, metadata: metadata);
      if (!mounted) {
        return;
      }
      setState(() {
        _installedApps = apps;
        _globalTarget = target;
        _globalResult = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo completar el analisis global: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGlobalScanning = false;
        });
      }
    }
  }

  ScanTarget _buildGlobalTarget(List<InstalledAndroidApp> apps) {
    final summary = _summarizeGlobalSignals(apps);

    return ScanTarget(
      name: 'Analisis global del dispositivo',
      sizeBytes: summary.userAppCount,
      source: ScanSource.observedBehavior,
      packageName:
          '${summary.userAppCount} apps de usuario, ${summary.highRiskAppCount} con senales',
      observedRiskScore: summary.riskScore,
      appCount: summary.userAppCount,
      systemAppCount: summary.systemAppCount,
      sensitivePermissionCount: summary.sensitivePermissionCount,
      highRiskAppCount: summary.highRiskAppCount,
    );
  }

  _GlobalSignalSummary _summarizeGlobalSignals(List<InstalledAndroidApp> apps) {
    final userApps = apps.where((app) => !_isPlatformApp(app)).toList();
    final systemAppCount = apps.length - userApps.length;
    var sensitivePermissionCount = 0;
    var highRiskAppCount = 0;
    var criticalAppCount = 0;

    for (final app in userApps) {
      final appSignalScore = _permissionSignalScore(app.requestedPermissions);
      sensitivePermissionCount += appSignalScore.permissionHits;
      if (appSignalScore.score >= 7) {
        highRiskAppCount++;
      }
      if (appSignalScore.score >= 11) {
        criticalAppCount++;
      }
    }

    final userAppCount = userApps.length;
    if (userAppCount == 0) {
      return _GlobalSignalSummary(
        userAppCount: 0,
        systemAppCount: systemAppCount,
        sensitivePermissionCount: 0,
        highRiskAppCount: 0,
        criticalAppCount: 0,
        riskScore: 0.08,
      );
    }

    final highRiskDensity = highRiskAppCount / userAppCount;
    final criticalDensity = criticalAppCount / userAppCount;
    final permissionDensity = (sensitivePermissionCount / (userAppCount * 6))
        .clamp(0.0, 1.0);
    var riskScore =
        (highRiskDensity * 0.48) +
        (criticalDensity * 0.34) +
        (permissionDensity * 0.10);

    if (userAppCount < 5) {
      riskScore *= 0.55;
    }

    return _GlobalSignalSummary(
      userAppCount: userAppCount,
      systemAppCount: systemAppCount,
      sensitivePermissionCount: sensitivePermissionCount,
      highRiskAppCount: highRiskAppCount,
      criticalAppCount: criticalAppCount,
      riskScore: riskScore.clamp(0.03, 0.95),
    );
  }

  bool _isPlatformApp(InstalledAndroidApp app) {
    final packageName = app.packageName.toLowerCase();
    return app.isSystemApp ||
        packageName.startsWith('android') ||
        packageName.startsWith('com.android.') ||
        packageName.startsWith('com.google.android.') ||
        packageName.startsWith('com.samsung.') ||
        packageName.startsWith('com.miui.') ||
        packageName.startsWith('com.xiaomi.') ||
        packageName.startsWith('com.huawei.') ||
        packageName.startsWith('com.oppo.') ||
        packageName.startsWith('com.vivo.') ||
        packageName.startsWith('com.motorola.');
  }

  _PermissionSignalScore _permissionSignalScore(List<String> permissions) {
    var score = 0;
    var permissionHits = 0;
    final seen = <String>{};

    for (final permission in permissions) {
      final normalized = permission.toUpperCase();
      final weight = _permissionWeight(normalized);
      if (weight == 0 || !seen.add(normalized)) {
        continue;
      }
      permissionHits++;
      score += weight;
    }

    return _PermissionSignalScore(score: score, permissionHits: permissionHits);
  }

  int _permissionWeight(String permission) {
    if (permission.contains('SEND_SMS')) return 4;
    if (permission.contains('SYSTEM_ALERT_WINDOW')) return 4;
    if (permission.contains('REQUEST_INSTALL_PACKAGES')) return 4;
    if (permission.contains('READ_SMS')) return 3;
    if (permission.contains('RECEIVE_SMS')) return 2;
    if (permission.contains('RECORD_AUDIO')) return 2;
    if (permission.contains('READ_CONTACTS')) return 1;
    if (permission.contains('READ_PHONE_STATE')) return 1;
    if (permission.contains('CALL_PHONE')) return 1;
    if (permission.contains('ACCESS_FINE_LOCATION')) return 1;
    if (permission.contains('CAMERA')) return 1;
    return 0;
  }

  void _selectSection(AppSection section) {
    setState(() {
      _section = section;
      _isNavOpen = false;
    });
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
                    ? _DetectorShell(
                        section: _section,
                        navOpen: _isNavOpen,
                        metadata: snapshot.data!,
                        globalTarget: _globalTarget ?? _defaultGlobalTarget,
                        globalResult: _globalResult,
                        installedApps: _installedApps,
                        error: _error,
                        isScanning: _isGlobalScanning,
                        onAnalyze: () => _runGlobalAnalysis(snapshot.data!),
                        onShieldTap: () {
                          setState(() {
                            _isNavOpen = !_isNavOpen;
                          });
                        },
                        onSelectSection: _selectSection,
                        onOpenUsageAccess:
                            _androidScanner.openUsageAccessSettings,
                      )
                    : const _LoadingView(),
              ),
              if (_externalApkTarget != null && snapshot.hasData)
                Positioned.fill(
                  child: ExternalApkAnalysisWindow(
                    metadata: snapshot.data!,
                    target: _externalApkTarget!,
                    result: _externalApkResult,
                    isScanning: _isExternalScanning,
                    error: _error,
                    onClose: () {
                      setState(() {
                        _externalApkTarget = null;
                        _externalApkResult = null;
                        _isExternalScanning = false;
                      });
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GlobalSignalSummary {
  const _GlobalSignalSummary({
    required this.userAppCount,
    required this.systemAppCount,
    required this.sensitivePermissionCount,
    required this.highRiskAppCount,
    required this.criticalAppCount,
    required this.riskScore,
  });

  final int userAppCount;
  final int systemAppCount;
  final int sensitivePermissionCount;
  final int highRiskAppCount;
  final int criticalAppCount;
  final double riskScore;
}

class _PermissionSignalScore {
  const _PermissionSignalScore({
    required this.score,
    required this.permissionHits,
  });

  final int score;
  final int permissionHits;
}

class _DetectorShell extends StatelessWidget {
  const _DetectorShell({
    required this.section,
    required this.navOpen,
    required this.metadata,
    required this.globalTarget,
    required this.globalResult,
    required this.installedApps,
    required this.error,
    required this.isScanning,
    required this.onAnalyze,
    required this.onShieldTap,
    required this.onSelectSection,
    required this.onOpenUsageAccess,
  });

  final AppSection section;
  final bool navOpen;
  final ModelMetadata metadata;
  final ScanTarget globalTarget;
  final ScanResult? globalResult;
  final List<InstalledAndroidApp> installedApps;
  final String? error;
  final bool isScanning;
  final VoidCallback onAnalyze;
  final VoidCallback onShieldTap;
  final ValueChanged<AppSection> onSelectSection;
  final Future<void> Function() onOpenUsageAccess;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth < 620 ? double.infinity : 470.0;

        return Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(navOpen ? 34.0 : 0.0, 0, 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppHeader(onShieldTap: onShieldTap),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: switch (section) {
                            AppSection.scanner => ScannerHomeScreen(
                              key: const ValueKey('scanner'),
                              metadata: metadata,
                              target: globalTarget,
                              result: globalResult,
                              error: error,
                              isScanning: isScanning,
                              onAnalyze: onAnalyze,
                            ),
                            AppSection.decision => DecisionInfoScreen(
                              key: const ValueKey('decision'),
                              result: globalResult,
                            ),
                            AppSection.data => DataInfoScreen(
                              key: const ValueKey('data'),
                              metadata: metadata,
                              target: globalTarget,
                              result: globalResult,
                              installedApps: installedApps,
                            ),
                            AppSection.xai => XaiInfoScreen(
                              key: const ValueKey('xai'),
                              result: globalResult,
                              isScanning: isScanning,
                            ),
                            AppSection.services => ServicesInfoScreen(
                              key: const ValueKey('services'),
                              installedApps: installedApps,
                              onOpenUsageAccess: onOpenUsageAccess,
                            ),
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (navOpen)
              Positioned.fill(
                left: 112,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => onSelectSection(section),
                  child: const SizedBox.expand(),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              left: navOpen ? 0 : -112,
              child: SideNavBar(selected: section, onSelect: onSelectSection),
            ),
          ],
        );
      },
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.onShieldTap});

  final VoidCallback onShieldTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Abrir navegacion',
          child: InkWell(
            onTap: onShieldTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.7),
                ),
                color: AppColors.cyan.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.security_rounded, color: AppColors.cyan),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MXAI Detector',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Mobile Android analysis',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lime.withValues(alpha: 0.7)),
            color: AppColors.lime.withValues(alpha: 0.09),
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.lime),
        ),
      ],
    );
  }
}

class SideNavBar extends StatelessWidget {
  const SideNavBar({super.key, required this.selected, required this.onSelect});

  final AppSection selected;
  final ValueChanged<AppSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(AppSection.scanner, Icons.radar_rounded, 'Inicio'),
      _NavItem(AppSection.decision, Icons.rule_rounded, 'Decision'),
      _NavItem(AppSection.data, Icons.layers_rounded, 'Datos'),
      _NavItem(AppSection.xai, Icons.psychology_alt_rounded, 'XAI'),
      _NavItem(AppSection.services, Icons.settings_suggest_rounded, 'SDK'),
    ];

    return SafeArea(
      right: false,
      child: Container(
        width: 104,
        margin: const EdgeInsets.fromLTRB(10, 10, 0, 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.panel.withValues(alpha: 0.96),
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(10, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.cyan),
            const SizedBox(height: 12),
            for (final item in items)
              _NavButton(
                item: item,
                selected: item.section == selected,
                onTap: () => onSelect(item.section),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.section, this.icon, this.label);

  final AppSection section;
  final IconData icon;
  final String label;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.voidBlack : AppColors.cyan;
    return Tooltip(
      message: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: selected ? AppColors.cyan : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.cyan : AppColors.line,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: color, size: 20),
              const SizedBox(height: 5),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScannerHomeScreen extends StatelessWidget {
  const ScannerHomeScreen({
    super.key,
    required this.metadata,
    required this.target,
    required this.result,
    required this.error,
    required this.isScanning,
    required this.onAnalyze,
  });

  final ModelMetadata metadata;
  final ScanTarget target;
  final ScanResult? result;
  final String? error;
  final bool isScanning;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('scanner-home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlobalSummaryCard(metadata: metadata, target: target, error: error),
        const SizedBox(height: 18),
        ScanStage(target: target, result: result, isScanning: isScanning),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isScanning ? null : onAnalyze,
            icon: isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar_rounded),
            label: Text(isScanning ? 'Analizando' : 'Analizar'),
          ),
        ),
        const SizedBox(height: 18),
        XaiGenerationPanel(
          result: result,
          isScanning: isScanning,
          enableReportGeneration: true,
        ),
      ],
    );
  }
}

class GlobalSummaryCard extends StatelessWidget {
  const GlobalSummaryCard({
    super.key,
    required this.metadata,
    required this.target,
    required this.error,
  });

  final ModelMetadata metadata;
  final ScanTarget target;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.android_rounded,
                color: AppColors.cyan,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Analisis global',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${metadata.featureCount} cols',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Listo para escanear',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            target.packageName ?? 'Apps, permisos y comportamiento observado',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

class ScanStage extends StatelessWidget {
  const ScanStage({
    super.key,
    required this.target,
    required this.result,
    required this.isScanning,
  });

  final ScanTarget target;
  final ScanResult? result;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final currentResult = result;
    final accent = currentResult == null
        ? AppColors.cyan
        : currentResult.label == DetectionLabel.malware
        ? AppColors.danger
        : AppColors.lime;

    return Panel(
      child: Column(
        children: [
          AnimatedScannerGauge(
            value: currentResult?.malwareProbability ?? 0,
            isScanning: isScanning,
            accent: accent,
            centerBuilder: (context, progress) {
              if (isScanning) {
                return _GaugeText(
                  headline: '${(progress * 100).round()}%',
                  title: 'Analizando',
                  subtitle: 'Apps del dispositivo',
                  accent: AppColors.cyan,
                );
              }
              if (currentResult != null) {
                return _GaugeText(
                  headline: currentResult.label.displayName,
                  title: 'Riesgo ${_percent(currentResult.malwareProbability)}',
                  subtitle: 'Confianza ${_percent(currentResult.confidence)}',
                  accent: accent,
                );
              }
              return const _GaugeText(
                headline: '0%',
                title: 'Listo para escanear',
                subtitle: 'Analisis global',
                accent: AppColors.cyan,
              );
            },
          ),
          const SizedBox(height: 14),
          Text(
            _stageStatus(result, isScanning),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  String _stageStatus(ScanResult? result, bool scanning) {
    if (scanning) {
      return 'Construyendo vector global de senales';
    }
    if (result != null) {
      return 'Decision lista: ${result.label.displayName}';
    }
    return 'Sin analisis ejecutado';
  }
}

class DecisionInfoScreen extends StatelessWidget {
  const DecisionInfoScreen({super.key, required this.result});

  final ScanResult? result;

  @override
  Widget build(BuildContext context) {
    final current = result;
    return SectionScaffold(
      title: 'Decision',
      icon: Icons.rule_rounded,
      children: [
        _InfoBlock(
          icon: Icons.model_training_rounded,
          title: 'Como decide el sistema',
          text:
              'MXAI convierte las senales observadas en un vector de 470 columnas. En analisis global la calibracion es conservadora: no basta contar permisos, se busca concentracion de senales en apps de usuario. El chat XAI solo explica, no clasifica.',
        ),
        const SizedBox(height: 14),
        if (current == null)
          const _InfoBlock(
            icon: Icons.pending_rounded,
            title: 'Sin decision',
            text:
                'Ejecuta Analizar en Inicio para generar una decision global.',
          )
        else
          DecisionScoreCard(result: current),
      ],
    );
  }
}

class DataInfoScreen extends StatelessWidget {
  const DataInfoScreen({
    super.key,
    required this.metadata,
    required this.target,
    required this.result,
    required this.installedApps,
  });

  final ModelMetadata metadata;
  final ScanTarget target;
  final ScanResult? result;
  final List<InstalledAndroidApp> installedApps;

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'Datos',
      icon: Icons.layers_rounded,
      children: [
        _DataRow(
          label: 'Vector esperado',
          value: '${metadata.featureCount} columnas',
        ),
        _DataRow(label: 'Modelo', value: metadata.modelName),
        _DataRow(label: 'ROC AUC', value: _percent(metadata.metrics.rocAuc)),
        _DataRow(label: 'Apps observadas', value: '${installedApps.length}'),
        _DataRow(label: 'Apps de usuario', value: '${target.appCount ?? 0}'),
        _DataRow(
          label: 'Apps sistema/OEM',
          value: '${target.systemAppCount ?? 0}',
        ),
        _DataRow(
          label: 'Permisos sensibles',
          value: '${target.sensitivePermissionCount ?? 0}',
        ),
        _DataRow(
          label: 'Apps con senales',
          value: '${target.highRiskAppCount ?? 0}',
        ),
        _DataRow(label: 'Fuente', value: target.sourceLabel),
        const SizedBox(height: 14),
        Text(
          'Importancia global',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.cyan),
        ),
        const SizedBox(height: 10),
        for (final item in metadata.globalImportance.take(6))
          _ProgressRow(
            label: item.feature,
            value: (item.importance / 0.026).clamp(0.02, 1),
            color: AppColors.cyan,
          ),
        const SizedBox(height: 12),
        if (result != null) ...[
          Text(
            'Importancia local',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.cyan),
          ),
          const SizedBox(height: 10),
          for (final factor in result!.localFactors.take(6))
            _ProgressRow(
              label: factor.feature,
              value: (factor.impact.abs() / 0.03).clamp(0.05, 1),
              color: factor.increasesRisk ? AppColors.danger : AppColors.lime,
            ),
        ],
      ],
    );
  }
}

class XaiInfoScreen extends StatelessWidget {
  const XaiInfoScreen({
    super.key,
    required this.result,
    required this.isScanning,
  });

  final ScanResult? result;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'Chat XAI',
      icon: Icons.psychology_alt_rounded,
      children: [
        CyberChatPanel(result: result, isScanning: isScanning),
        const SizedBox(height: 14),
        const _InfoBlock(
          icon: Icons.chat_rounded,
          title: 'Rol del chat',
          text:
              'Este modo usa mxai-cyber-chat para responder solo preguntas defensivas de ciberseguridad relacionadas con MXAI. El reporte del analisis global queda en Inicio.',
        ),
      ],
    );
  }
}

class ServicesInfoScreen extends StatelessWidget {
  const ServicesInfoScreen({
    super.key,
    required this.installedApps,
    required this.onOpenUsageAccess,
  });

  final List<InstalledAndroidApp> installedApps;
  final Future<void> Function() onOpenUsageAccess;

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: 'SDK Android',
      icon: Icons.settings_suggest_rounded,
      children: [
        const _InfoBlock(
          icon: Icons.install_mobile_rounded,
          title: 'Activacion fuera de la app',
          text:
              'El SDK no reemplaza la descarga ni el instalador. Primero descarga el APK y despues compartelo con MXAI para abrir la ventana externa de analisis con explicabilidad.',
        ),
        const SizedBox(height: 14),
        _DataRow(label: 'Apps cacheadas', value: '${installedApps.length}'),
        const _DataRow(label: 'Permiso', value: 'QUERY_ALL_PACKAGES'),
        const _DataRow(label: 'Servicio', value: 'AppAnalysisService'),
        const _DataRow(label: 'Intent', value: 'SEND APK post-descarga'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => onOpenUsageAccess(),
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Abrir acceso de uso'),
          ),
        ),
      ],
    );
  }
}

class ExternalApkAnalysisWindow extends StatelessWidget {
  const ExternalApkAnalysisWindow({
    super.key,
    required this.metadata,
    required this.target,
    required this.result,
    required this.isScanning,
    required this.error,
    required this.onClose,
  });

  final ModelMetadata metadata;
  final ScanTarget target;
  final ScanResult? result;
  final bool isScanning;
  final String? error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.voidBlack,
      child: Stack(
        children: [
          const Positioned.fill(child: FuturisticBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                          ),
                          Expanded(
                            child: Text(
                              'Analisis externo',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Text(
                            '${metadata.featureCount} cols',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: AppColors.cyan),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.file_present_rounded,
                                  color: AppColors.cyan,
                                ),
                                SizedBox(width: 10),
                                Expanded(child: Text('APK externo recibido')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              target.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              target.path ?? target.sizeLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.muted),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                error!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.danger),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      ScanStage(
                        target: target,
                        result: result,
                        isScanning: isScanning,
                      ),
                      const SizedBox(height: 18),
                      XaiGenerationPanel(
                        result: result,
                        isScanning: isScanning,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        key: ValueKey(title),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class XaiGenerationPanel extends StatefulWidget {
  const XaiGenerationPanel({
    super.key,
    required this.result,
    required this.isScanning,
    this.enableReportGeneration = false,
  });

  final ScanResult? result;
  final bool isScanning;
  final bool enableReportGeneration;

  @override
  State<XaiGenerationPanel> createState() => _XaiGenerationPanelState();
}

class _XaiGenerationPanelState extends State<XaiGenerationPanel> {
  final _ollama = const OllamaService();

  bool _isGenerating = false;
  String? _ollamaText;
  String? _ollamaError;

  @override
  void didUpdateWidget(covariant XaiGenerationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _ollamaText = null;
      _ollamaError = null;
    }
  }

  Future<void> _generateReport() async {
    final result = widget.result;
    if (result == null || _isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _ollamaError = null;
    });

    try {
      final text = await _ollama.generateAnalysisReport(result);
      if (!mounted) return;
      setState(() {
        _ollamaText = text.isEmpty ? null : text;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ollamaError = error is OllamaException
            ? error.toString()
            : _ollamaConnectionMessage(_ollama.baseUrl);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_rounded, color: AppColors.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Generacion XAI',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                widget.result == null
                    ? 'Ollama'
                    : widget.result!.label.displayName,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (widget.isScanning || _isGenerating) {
      return const _GeneratingText(key: ValueKey('generating'));
    }

    final current = widget.result;
    if (current == null) {
      return Text(
        'La explicacion aparecera aqui despues de la decision del modelo. El LLM no clasifica; solo traduce probabilidades y factores locales a texto.',
        key: const ValueKey('empty-xai'),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      );
    }

    if (widget.enableReportGeneration) {
      return _ReportMode(
        key: const ValueKey('report-mode'),
        fallback: _xaiText(current),
        ollamaText: _ollamaText,
        error: _ollamaError,
        onGenerate: _generateReport,
      );
    }

    return Text(
      _xaiText(current),
      key: const ValueKey('xai-result'),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  String _xaiText(ScanResult result) {
    final top = result.localFactors
        .take(3)
        .map((factor) => factor.feature)
        .join(', ');
    final direction = result.label == DetectionLabel.malware
        ? 'muestran concentracion suficiente para elevar el riesgo'
        : 'no muestran concentracion suficiente para elevar el riesgo global';
    return 'El modelo predice ${result.label.displayName} con ${_percent(result.confidence)} de confianza. Las senales locales mas relevantes son $top; estas $direction. Cuando Ollama este conectado, esta base se convertira en una explicacion natural y trazable.';
  }
}

class CyberChatPanel extends StatefulWidget {
  const CyberChatPanel({
    super.key,
    required this.result,
    required this.isScanning,
  });

  final ScanResult? result;
  final bool isScanning;

  @override
  State<CyberChatPanel> createState() => _CyberChatPanelState();
}

class _CyberChatPanelState extends State<CyberChatPanel> {
  final _ollama = const OllamaService();
  final _questionController = TextEditingController();

  bool _isGenerating = false;
  String? _response;
  String? _error;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _askChat() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _isGenerating) {
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final text = await _ollama.askCyberChat(
        question: question,
        result: widget.result,
      );
      if (!mounted) return;
      setState(() {
        _response = text.isEmpty ? null : text;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is OllamaException
            ? error.toString()
            : _ollamaConnectionMessage(_ollama.baseUrl);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_rounded, color: AppColors.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chatbot XAI',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                'mxai-cyber-chat',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.cyan),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: widget.isScanning || _isGenerating
                ? const _GeneratingText(key: ValueKey('chat-generating'))
                : _ChatMode(
                    key: const ValueKey('chat-mode'),
                    controller: _questionController,
                    response: _response,
                    error: _error,
                    onAsk: _askChat,
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReportMode extends StatelessWidget {
  const _ReportMode({
    super.key,
    required this.fallback,
    required this.ollamaText,
    required this.error,
    required this.onGenerate,
  });

  final String fallback;
  final String? ollamaText;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ollamaText ?? fallback,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.description_rounded),
            label: const Text('Generar reporte Ollama'),
          ),
        ),
      ],
    );
  }
}

class _ChatMode extends StatelessWidget {
  const _ChatMode({
    super.key,
    required this.controller,
    required this.response,
    required this.error,
    required this.onAsk,
  });

  final TextEditingController controller;
  final String? response;
  final String? error;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onAsk(),
          decoration: InputDecoration(
            hintText: 'Pregunta sobre ciberseguridad o MXAI',
            prefixIcon: const Icon(Icons.chat_rounded),
            suffixIcon: IconButton(
              tooltip: 'Enviar',
              onPressed: onAsk,
              icon: const Icon(Icons.send_rounded),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 12),
        if (response == null && error == null)
          Text(
            'Este chatbot esta limitado a ciberseguridad defensiva y preguntas sobre MXAI Detector.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          )
        else if (response != null)
          Text(response!, style: Theme.of(context).textTheme.bodyMedium),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class DecisionScoreCard extends StatelessWidget {
  const DecisionScoreCard({super.key, required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final accent = result.label == DetectionLabel.malware
        ? AppColors.danger
        : AppColors.lime;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.42)),
        color: AppColors.ink.withValues(alpha: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.label.displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(color: accent),
                ),
              ),
              Text(_percent(result.confidence)),
            ],
          ),
          const SizedBox(height: 14),
          _ProgressRow(
            label: 'Malware',
            value: result.malwareProbability,
            color: AppColors.danger,
          ),
          _ProgressRow(
            label: 'Benign',
            value: result.benignProbability,
            color: AppColors.lime,
          ),
        ],
      ),
    );
  }
}

class _GaugeText extends StatelessWidget {
  const _GaugeText({
    required this.headline,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String headline;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          child: Text(
            headline,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: accent,
              fontSize: 42,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        SizedBox(
          width: 170,
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class AnimatedScannerGauge extends StatefulWidget {
  const AnimatedScannerGauge({
    super.key,
    required this.value,
    required this.isScanning,
    required this.accent,
    required this.centerBuilder,
  });

  final double value;
  final bool isScanning;
  final Color accent;
  final Widget Function(BuildContext context, double progress) centerBuilder;

  @override
  State<AnimatedScannerGauge> createState() => _AnimatedScannerGaugeState();
}

class _AnimatedScannerGaugeState extends State<AnimatedScannerGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    if (widget.isScanning) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedScannerGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isScanning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scanningProgress = 0.18 + (_controller.value * 0.68);
        final value = widget.isScanning ? scanningProgress : widget.value;
        return SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size.square(260),
                painter: _ScannerGaugePainter(
                  value: value,
                  sweep: _controller.value,
                  accent: widget.accent,
                  scanning: widget.isScanning,
                ),
              ),
              widget.centerBuilder(context, value),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerGaugePainter extends CustomPainter {
  const _ScannerGaugePainter({
    required this.value,
    required this.sweep,
    required this.accent,
    required this.scanning,
  });

  final double value;
  final double sweep;
  final Color accent;
  final bool scanning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 18;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = AppColors.ink;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [
          accent.withValues(alpha: 0.18),
          accent,
          AppColors.lime.withValues(alpha: scanning ? 0.8 : 0.25),
        ],
      ).createShader(rect);
    final pulse = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = accent.withValues(alpha: scanning ? 0.25 : 0.12);
    final tick = Paint()
      ..strokeWidth = 1
      ..color = AppColors.cyan.withValues(alpha: 0.24);

    canvas.drawCircle(center, radius, base);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, progress);
    canvas.drawCircle(
      center,
      radius - 34 + (scanning ? math.sin(sweep * math.pi * 2) * 5 : 0),
      pulse,
    );

    for (var i = 0; i < 32; i++) {
      final angle = -math.pi / 2 + (math.pi * 2 * i / 32);
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - 28),
        center.dy + math.sin(angle) * (radius - 28),
      );
      final outer = Offset(
        center.dx + math.cos(angle) * (radius - 20),
        center.dy + math.sin(angle) * (radius - 20),
      );
      canvas.drawLine(inner, outer, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.sweep != sweep ||
        oldDelegate.accent != accent ||
        oldDelegate.scanning != scanning;
  }
}

class _GeneratingText extends StatelessWidget {
  const _GeneratingText({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _SkeletonLine(widthFactor: 1),
        SizedBox(height: 9),
        _SkeletonLine(widthFactor: 0.78),
        SizedBox(height: 9),
        _SkeletonLine(widthFactor: 0.55),
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: AppColors.cyan.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
        color: AppColors.ink.withValues(alpha: 0.68),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(_percent(value)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.voidBlack,
            ),
          ),
        ],
      ),
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

class FuturisticBackground extends StatelessWidget {
  const FuturisticBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.voidBlack, Color(0xFF071015), Color(0xFF0B1115)],
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
      ..color = AppColors.cyan.withValues(alpha: 0.022)
      ..strokeWidth = 1;
    final strongPaint = Paint()
      ..color = AppColors.lime.withValues(alpha: 0.032)
      ..strokeWidth = 1.2;

    const spacing = 86.0;
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final path = Path()
      ..moveTo(size.width * 0.07, size.height * 0.22)
      ..lineTo(size.width * 0.36, size.height * 0.22)
      ..lineTo(size.width * 0.52, size.height * 0.36)
      ..lineTo(size.width * 0.86, size.height * 0.36)
      ..moveTo(size.width * 0.3, size.height * 0.78)
      ..lineTo(size.width * 0.64, size.height * 0.78)
      ..lineTo(size.width * 0.82, size.height * 0.9);
    canvas.drawPath(path, strongPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  static const danger = Color(0xFFFF5570);
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _ollamaConnectionMessage(String baseUrl) {
  return 'No pude conectar con Ollama en $baseUrl. En telefono fisico 127.0.0.1 apunta al telefono; instala con scripts\\install_to_phone.ps1 -OllamaBaseUrl "http://IP_DE_TU_PC:11434" y verifica que Ollama este escuchando en la red local.';
}
