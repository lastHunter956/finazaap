package com.example.finazaap

import android.app.ActivityManager
import android.content.Context
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
                } else {
                    result.notImplemented()
                }
            }
    }
}
