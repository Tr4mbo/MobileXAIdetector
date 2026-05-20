package com.example.mobile_x_ai_detector

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null
    private var pendingExternalApk: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pendingExternalApk = extractExternalApk(intent)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mxai_detector/app_scanner"
        )

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "listInstalledApps" -> result.success(listInstalledApps())
                "getInitialExternalApk" -> result.success(pendingExternalApk)
                "openUsageAccessSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "openAppDetails" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("missing_package", "packageName is required", null)
                    } else {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val externalApk = extractExternalApk(intent)
        if (externalApk != null) {
            pendingExternalApk = externalApk
            methodChannel?.invokeMethod("externalApkReceived", externalApk)
        }
    }

    private fun listInstalledApps(): List<Map<String, Any?>> {
        val flags = PackageManager.GET_PERMISSIONS
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getInstalledPackages(
                PackageManager.PackageInfoFlags.of(flags.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getInstalledPackages(flags)
        }

        return packages
            .filter { it.packageName != packageName }
            .map { packageInfo -> packageInfo.toFlutterMap(packageManager) }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    private fun extractExternalApk(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null

        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            }
            else -> null
        } ?: return null

        val type = intent.type ?: contentResolver.getType(uri)
        val displayName = queryDisplayName(uri) ?: uri.lastPathSegment ?: "external.apk"
        val isApk = type == "application/vnd.android.package-archive" ||
            displayName.endsWith(".apk", ignoreCase = true) ||
            uri.toString().endsWith(".apk", ignoreCase = true)

        if (!isApk) return null

        return mapOf(
            "name" to displayName,
            "uri" to uri.toString(),
            "sizeBytes" to querySize(uri),
            "mimeType" to type
        )
    }

    private fun queryDisplayName(uri: Uri): String? {
        return contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
        }
    }

    private fun querySize(uri: Uri): Long {
        return contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (index >= 0 && cursor.moveToFirst()) cursor.getLong(index) else 0L
        } ?: 0L
    }
}

private fun PackageInfo.toFlutterMap(packageManager: PackageManager): Map<String, Any?> {
    val appInfo = applicationInfo
    val label = appInfo?.loadLabel(packageManager)?.toString() ?: packageName
    val versionCodeValue = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        longVersionCode
    } else {
        @Suppress("DEPRECATION")
        versionCode.toLong()
    }

    return mapOf(
        "packageName" to packageName,
        "label" to label,
        "versionName" to (versionName ?: "unknown"),
        "versionCode" to versionCodeValue,
        "firstInstallTime" to firstInstallTime,
        "lastUpdateTime" to lastUpdateTime,
        "requestedPermissions" to (requestedPermissions?.toList() ?: emptyList<String>()),
        "sourceDir" to appInfo?.sourceDir
    )
}
