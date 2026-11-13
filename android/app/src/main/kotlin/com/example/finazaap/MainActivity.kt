package com.example.finazaap

import android.app.ActivityManager
import android.content.Context
import android.os.StatFs
import android.os.Environment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
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
    }
}
