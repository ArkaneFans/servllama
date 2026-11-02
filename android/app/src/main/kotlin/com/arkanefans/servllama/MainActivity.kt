package com.arkanefans.servllama

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Environment
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine = AppHost.engine(context)
    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/file_export").setMethodCallHandler(null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/model_storage").setMethodCallHandler(null)
        pendingModelStorageResult?.error("activity_detached", "Model selection interrupted", null)
        pendingModelStorageResult = null
        pendingExportResult?.error("activity_detached", "Export interrupted; retry from the active screen", null)
        pendingExportResult = null
        pendingExportSourcePath = null
        pendingExportFileName = null
        pendingExportMimeType = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingModelStorageResult: MethodChannel.Result? = null
    private var pendingExportSourcePath: String? = null
    private var pendingExportFileName: String? = null
    private var pendingExportMimeType: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.arkanefans.servllama/model_storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAccess" -> requestModelStorageAccess(result)
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
        if (requestCode == REQUEST_MODEL_STORAGE) {
            completeModelStorageAccess()
            return
        }
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

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_MODEL_STORAGE) completeModelStorageAccess()
    }

    private fun hasModelStorageAccess(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }

    private fun completeModelStorageAccess() {
        val result = pendingModelStorageResult ?: return
        pendingModelStorageResult = null
        result.success(if (hasModelStorageAccess()) Environment.getExternalStorageDirectory().path else null)
    }

    private fun requestModelStorageAccess(result: MethodChannel.Result) {
        if (hasModelStorageAccess()) {
            result.success(Environment.getExternalStorageDirectory().path)
            return
        }
        if (pendingModelStorageResult != null) {
            result.error("permission_busy", "Storage authorization is already in progress", null)
            return
        }
        pendingModelStorageResult = result
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName"))
                try {
                    startActivityForResult(intent, REQUEST_MODEL_STORAGE)
                } catch (_: android.content.ActivityNotFoundException) {
                    startActivityForResult(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION), REQUEST_MODEL_STORAGE)
                }
            } else {
                requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), REQUEST_MODEL_STORAGE)
            }
        } catch (error: Exception) {
            pendingModelStorageResult = null
            result.error("permission_failed", "Unable to open storage authorization", null)
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
        if (pendingExportResult != null) {
            result.error("export_busy", "An export is awaiting permission", null)
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

    companion object {
        private const val REQUEST_WRITE_EXTERNAL_STORAGE = 1001
        private const val REQUEST_MODEL_STORAGE = 1002
    }
}
