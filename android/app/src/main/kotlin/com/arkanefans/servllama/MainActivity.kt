package com.arkanefans.servllama

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportSourcePath: String? = null
    private var pendingExportFileName: String? = null
    private var pendingExportMimeType: String? = null

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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/download_environment",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "networkTransport" -> result.success(resolveNetworkTransport())
                "availableStorageBytes" -> {
                    result.success(StatFs(filesDir.absolutePath).availableBytes)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/file_export",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> saveToDownloads(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_WRITE_EXTERNAL_STORAGE) {
            return
        }
        val result = pendingExportResult
        val sourcePath = pendingExportSourcePath
        val fileName = pendingExportFileName
        val mimeType = pendingExportMimeType
        pendingExportResult = null
        pendingExportSourcePath = null
        pendingExportFileName = null
        pendingExportMimeType = null
        if (result == null || sourcePath == null || fileName == null || mimeType == null) {
            return
        }
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            completeExport(result, sourcePath, fileName, mimeType)
        } else {
            result.error("permission_denied", "Storage permission denied", null)
        }
    }

    private fun saveToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType") ?: "text/plain"
        if (sourcePath.isNullOrEmpty() || fileName.isNullOrEmpty()) {
            result.error("invalid_args", "sourcePath and fileName are required", null)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ||
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            completeExport(result, sourcePath, fileName, mimeType)
            return
        }
        pendingExportResult = result
        pendingExportSourcePath = sourcePath
        pendingExportFileName = fileName
        pendingExportMimeType = mimeType
        requestPermissions(
            arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
            REQUEST_WRITE_EXTERNAL_STORAGE,
        )
    }

    private fun completeExport(
        result: MethodChannel.Result,
        sourcePath: String,
        fileName: String,
        mimeType: String,
    ) {
        try {
            result.success(
                DownloadsExporter.saveToDownloads(this, sourcePath, fileName, mimeType),
            )
        } catch (error: Exception) {
            result.error("export_failed", error.message, null)
        }
    }

    private fun resolveNetworkTransport(): String {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork ?: return "none"
        val capabilities = manager.getNetworkCapabilities(network) ?: return "none"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            else -> "other"
        }
    }

    companion object {
        private const val REQUEST_WRITE_EXTERNAL_STORAGE = 1001
    }
}
