package com.example.finazaap

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    @Volatile
    private var cachedInstalledApps: List<Map<String, Any?>>? = null

    @Volatile
    private var cachedAppsTimestampMs: Long = 0L

    private val appsCacheTtlMs = 5L * 60 * 1000

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
                      "com.example.finazaap/device_info")
            .setMethodCallHandler { call, result ->
                if (call.method == "getTotalRam") {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    val memInfo = ActivityManager.MemoryInfo()
                    am.getMemoryInfo(memInfo)
                    result.success(memInfo.totalMem)
                } else if (call.method == "getFreeDiskSpace") {
                    try {
                        val stat = StatFs(Environment.getDataDirectory().path)
                        val bytesAvailable = stat.blockSizeLong * stat.availableBlocksLong
                        val megabytesAvailable = bytesAvailable.toDouble() / (1024.0 * 1024.0)
                        result.success(megabytesAvailable)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
                      "com.example.finazaap/notifications_apps")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledApps" -> {
                        val forceRefresh = call.argument<Boolean>("forceRefresh") ?: false
                        val cached = cachedInstalledApps
                        val isCacheFresh = cached != null &&
                            (System.currentTimeMillis() - cachedAppsTimestampMs) < appsCacheTtlMs
                        if (!forceRefresh && isCacheFresh) {
                            result.success(cached)
                            return@setMethodCallHandler
                        }
                        Thread {
                            try {
                                val apps = loadLaunchableApps()
                                cachedInstalledApps = apps
                                cachedAppsTimestampMs = System.currentTimeMillis()
                                runOnUiThread { result.success(apps) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("APP_LIST_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    }
                    "isNotificationAccessGranted" -> {
                        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
                        val granted = enabledPackages.contains(packageName)
                        if (granted && !MoneoNotificationListenerService.isListenerConnected()) {
                            MoneoNotificationListenerService.ensureServiceBound(this)
                        }
                        result.success(granted)
                    }
                    "getListenerDiagnostics" -> {
                        val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(this)
                        val granted = enabledPackages.contains(packageName)
                        if (granted && !MoneoNotificationListenerService.isListenerConnected()) {
                            MoneoNotificationListenerService.ensureServiceBound(this)
                        }
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val ignoringBatteryOpt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            pm?.isIgnoringBatteryOptimizations(packageName) ?: true
                        } else {
                            true
                        }
                        result.success(
                            mapOf(
                                "permissionGranted" to granted,
                                "listenerConnected" to MoneoNotificationListenerService.isListenerConnected(),
                                "batteryOptimizationIgnored" to ignoringBatteryOpt
                            )
                        )
                    }
                    "openNotificationAccessSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_ERROR", e.message, null)
                        }
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            } else {
                                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", packageName, null)
                                }
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            try {
                                val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", packageName, null)
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(fallback)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("BATTERY_SETTINGS_ERROR", e2.message, null)
                            }
                        }
                    }
                    "syncCaptureConfig" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val packages = call.argument<List<String>>("allowedPackages") ?: emptyList()
                        MoneoNotificationListenerService.syncConfig(
                            this,
                            enabled,
                            packages.toSet()
                        )
                        result.success(true)
                    }
                    "peekQueuedNotifications" -> {
                        result.success(MoneoNotificationListenerService.peekQueue(this))
                    }
                    "ackQueuedNotifications" -> {
                        val ids = call.argument<List<String>>("ids") ?: emptyList()
                        val removed = MoneoNotificationListenerService.ackQueueIds(
                            this,
                            ids.toSet()
                        )
                        result.success(removed)
                    }
                    "fetchActiveNotifications" -> {
                        val collected = MoneoNotificationListenerService.collectActiveNotifications(this)
                        result.success(collected)
                    }
                    "clearNativeQueue" -> {
                        MoneoNotificationListenerService.clearQueue(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger,
                     "com.example.finazaap/notifications_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    MoneoNotificationListenerService.setEventListener { eventMap ->
                        runOnUiThread {
                            events?.success(eventMap)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    MoneoNotificationListenerService.setEventListener(null)
                }
            })
    }

    private fun loadLaunchableApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(mainIntent, 0)
        }

        val seenPackages = HashSet<String>()
        val apps = ArrayList<Map<String, Any?>>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == packageName || !seenPackages.add(pkg)) continue

            val label = info.loadLabel(pm)?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: pkg
            val iconBytes = try {
                drawableToPngBytes(info.loadIcon(pm))
            } catch (_: Exception) {
                null
            }

            apps.add(
                mapOf(
                    "packageName" to pkg,
                    "appName" to label,
                    "iconBytes" to iconBytes
                )
            )
        }

        apps.sortBy { (it["appName"] as? String)?.lowercase() ?: "" }
        return apps
    }

    private fun drawableToPngBytes(drawable: Drawable): ByteArray? {
        val size = 48
        val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(canvas)
            bmp
        }
        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
        return stream.toByteArray()
    }
}
