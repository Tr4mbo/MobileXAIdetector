import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/detector_models.dart';

class AndroidAppScannerService {
  const AndroidAppScannerService();

  static const _channel = MethodChannel('mxai_detector/app_scanner');
  static final _externalApkController =
      StreamController<ScanTarget>.broadcast();
  static bool _handlerRegistered = false;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<InstalledAndroidApp>> listInstalledApps() async {
    if (!isSupported) {
      return const [];
    }

    final response = await _channel.invokeListMethod<dynamic>(
      'listInstalledApps',
    );

    return (response ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(InstalledAndroidApp.fromMap)
        .toList(growable: false);
  }

  Stream<ScanTarget> get externalApkStream => _externalApkController.stream;

  Future<void> initializeExternalApkListener() async {
    if (!isSupported || _handlerRegistered) {
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'externalApkReceived') {
        final target = _targetFromExternalApk(call.arguments);
        if (target != null) {
          _externalApkController.add(target);
        }
      }
    });
    _handlerRegistered = true;
  }

  Future<ScanTarget?> getInitialExternalApk() async {
    if (!isSupported) {
      return null;
    }

    final response = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getInitialExternalApk',
    );
    return _targetFromExternalApk(response);
  }

  Future<void> openUsageAccessSettings() async {
    if (isSupported) {
      await _channel.invokeMethod<void>('openUsageAccessSettings');
    }
  }

  Future<void> openAppDetails(String packageName) async {
    if (isSupported) {
      await _channel.invokeMethod<void>('openAppDetails', {
        'packageName': packageName,
      });
    }
  }

  ScanTarget? _targetFromExternalApk(Object? value) {
    if (value is! Map<dynamic, dynamic>) {
      return null;
    }

    return ScanTarget(
      name: value['name'] as String? ?? 'external.apk',
      sizeBytes: (value['sizeBytes'] as num?)?.toInt() ?? 0,
      path: value['uri'] as String?,
      source: ScanSource.apkFile,
    );
  }
}
