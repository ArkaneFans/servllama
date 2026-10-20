package com.arkanefans.servllama

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.StatFs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/** One business isolate per process; Activity recreation only reattaches plugins.
 * The foreground_task engine is notification-only and owns no model handles. */
object AppHost {
    private var engine: FlutterEngine? = null
    @Synchronized fun engine(context: Context): FlutterEngine {
        engine?.let { return it }
        val app = context.applicationContext
        val created = FlutterEngine(app)
        AudioDecoder(app, created.dartExecutor.binaryMessenger)
        MethodChannel(created.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/native_libs").setMethodCallHandler { call, result ->
            if (call.method == "getNativeLibraryDir") {
                result.success(app.applicationInfo.nativeLibraryDir)
            } else result.notImplemented()
        }
        MethodChannel(created.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/download_environment").setMethodCallHandler { call, result ->
            when (call.method) {
                "availableStorageBytes" -> result.success(StatFs(app.filesDir.absolutePath).availableBytes)
                "networkTransport" -> {
                    val manager = app.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val caps = manager.activeNetwork?.let { manager.getNetworkCapabilities(it) }
                    result.success(when {
                        caps == null -> "none"
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                        caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                        else -> "other"
                    })
                }
                else -> result.notImplemented()
            }
        }
        created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        engine = created
        return created
    }
}
