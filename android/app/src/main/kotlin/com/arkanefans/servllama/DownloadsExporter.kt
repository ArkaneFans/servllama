package com.arkanefans.servllama

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream

object DownloadsExporter {
    fun saveToDownloads(
        context: Context,
        sourcePath: String,
        fileName: String,
        mimeType: String,
    ): String {
        val source = File(sourcePath)
        require(source.exists()) { "source file missing: $sourcePath" }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveWithMediaStore(context, source, fileName, mimeType)
        } else {
            saveLegacy(context, source, fileName, mimeType)
        }
    }

    private fun saveWithMediaStore(
        context: Context,
        source: File,
        fileName: String,
        mimeType: String,
    ): String {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(MediaStore.Downloads.IS_PENDING, 1)
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = resolver.insert(collection, values)
            ?: error("Unable to create download entry")
        try {
            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input -> input.copyTo(output) }
            } ?: error("Unable to open download stream")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }

        val displayName = resolver.query(
            uri,
            arrayOf(MediaStore.Downloads.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else fileName
        } ?: fileName
        return publicDownloadsFile(displayName).absolutePath
    }

    private fun saveLegacy(
        context: Context,
        source: File,
        fileName: String,
        mimeType: String,
    ): String {
        val dir = publicDownloadsDir()
        if (!dir.exists() && !dir.mkdirs()) {
            error("Unable to create downloads directory")
        }
        val target = uniqueFile(dir, fileName)
        source.copyTo(target, overwrite = false)
        MediaScannerConnection.scanFile(
            context,
            arrayOf(target.absolutePath),
            arrayOf(mimeType),
            null,
        )
        return target.absolutePath
    }

    @Suppress("DEPRECATION")
    private fun publicDownloadsDir(): File {
        return Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
    }

    private fun publicDownloadsFile(fileName: String): File {
        return File(publicDownloadsDir(), fileName)
    }

    private fun uniqueFile(dir: File, fileName: String): File {
        val candidate = File(dir, fileName)
        if (!candidate.exists()) {
            return candidate
        }
        val dot = fileName.lastIndexOf('.')
        val stem = if (dot > 0) fileName.substring(0, dot) else fileName
        val ext = if (dot > 0) fileName.substring(dot) else ""
        var index = 1
        while (true) {
            val next = File(dir, "$stem ($index)$ext")
            if (!next.exists()) {
                return next
            }
            index++
        }
    }
}
