package com.arkanefans.servllama

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/native_libs",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNativeLibraryDir" -> result.success(applicationInfo.nativeLibraryDir)
                else -> result.notImplemented()
            }
        }
    }
}
