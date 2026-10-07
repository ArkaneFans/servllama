package com.arkanefans.servllama

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/** Streams Android-supported audio into PCM WAV; never holds the whole file. */
class AudioDecoder(private val context: Context, messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val cancelled = ConcurrentHashMap.newKeySet<String>()
    private val pending = ConcurrentHashMap.newKeySet<String>()
    init {
        MethodChannel(messenger, "com.arkanefans.servllama/audio").setMethodCallHandler { call, result ->
            val id = call.argument<String>("id") ?: ""
            when (call.method) {
                "cancelDecode" -> { if (pending.contains(id)) cancelled.add(id); result.success(null) }
                "decode" -> {
                    val source = call.argument<String>("source")
                    val destination = call.argument<String>("destination")
                    if (id.isEmpty() || source == null || destination == null) {
                        result.error("invalid_audio", "Missing audio path", null)
                    } else if (pending.size >= 8 || !pending.add(id)) {
                        result.error("audio_busy", "Audio decoder is busy", null)
                    } else worker.execute {
                        try {
                            decode(id, owned(source), owned(destination))
                            main.post { result.success(null) }
                        } catch (e: Exception) {
                            main.post { result.error("audio_decode", e.message, null) }
                        } finally { pending.remove(id); cancelled.remove(id) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun owned(path: String): File {
        val file = File(path).canonicalFile
        val roots = listOf(context.filesDir, context.cacheDir)
        require(roots.any { file.path.startsWith(it.canonicalPath + File.separator) }) { "Audio path is outside app storage" }
        return file
    }
    private fun decode(id: String, source: File, destination: File) {
        require(source.length() in 1..(512L * 1024 * 1024)) { "Audio file size limit" }
        require(source != destination) { "Audio output must be a separate file" }
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        var success = false
        try {
            extractor.setDataSource(source.path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: error("No audio track")
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            if (format.containsKey(MediaFormat.KEY_DURATION)) {
                require(format.getLong(MediaFormat.KEY_DURATION) <= 10_800_000_000L) { "Audio is longer than 3 hours" }
            }
            format.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            decoder = codec
            codec.configure(format, null, null, 0)
            codec.start()
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var bits = 16
            var dataBytes = 0L
            var inputDone = false
            var outputDone = false
            var lastProgress = SystemClock.elapsedRealtime()
            val info = MediaCodec.BufferInfo()
            RandomAccessFile(destination, "rw").use { output ->
                output.setLength(0); output.write(ByteArray(44))
                while (!outputDone) {
                    check(!cancelled.contains(id)) { "Audio decoding cancelled" }
                    check(SystemClock.elapsedRealtime() - lastProgress < 30_000) { "Audio decoder stalled" }
                    if (!inputDone) {
                        val index = codec.dequeueInputBuffer(10_000)
                        if (index >= 0) {
                            lastProgress = SystemClock.elapsedRealtime()
                            val buffer = codec.getInputBuffer(index)!!
                            val size = extractor.readSampleData(buffer, 0)
                            if (size < 0) {
                                codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM); inputDone = true
                            } else {
                                codec.queueInputBuffer(index, 0, size, extractor.sampleTime, 0); extractor.advance()
                            }
                        }
                    }
                    val index = codec.dequeueOutputBuffer(info, 10_000)
                    if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        val decoded = codec.outputFormat
                        require(dataBytes == 0L) { "Audio format changed midstream" }
                        rate = decoded.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        channels = decoded.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                        val encoding = if (decoded.containsKey(MediaFormat.KEY_PCM_ENCODING)) decoded.getInteger(MediaFormat.KEY_PCM_ENCODING) else AudioFormat.ENCODING_PCM_16BIT
                        require(encoding == AudioFormat.ENCODING_PCM_16BIT || encoding == AudioFormat.ENCODING_PCM_FLOAT) { "Unsupported PCM encoding" }
                        bits = if (encoding == AudioFormat.ENCODING_PCM_FLOAT) 32 else 16
                        require(rate in 8000..192000 && channels in 1..8)
                    } else if (index >= 0) {
                        lastProgress = SystemClock.elapsedRealtime()
                        try {
                            if (info.size > 0) {
                                val buffer = codec.getOutputBuffer(index)!!
                                buffer.position(info.offset); buffer.limit(info.offset + info.size)
                                val chunk = ByteArray(minOf(info.size, 65536))
                                while (buffer.hasRemaining()) {
                                    val size = minOf(chunk.size, buffer.remaining())
                                    buffer.get(chunk, 0, size); output.write(chunk, 0, size); dataBytes += size
                                }
                                require(dataBytes <= 512L * 1024 * 1024) { "Decoded audio exceeds 512 MiB" }
                                require(dataBytes <= rate.toLong() * channels * (bits / 8) * 10800) { "Audio is longer than 3 hours" }
                            }
                            outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                        } finally { codec.releaseOutputBuffer(index, false) }
                    }
                }
                require(dataBytes > 0) { "Audio is empty" }
                val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
                header.put("RIFF".toByteArray()).putInt((dataBytes + 36).toInt()).put("WAVEfmt ".toByteArray())
                header.putInt(16).putShort((if (bits == 32) 3 else 1).toShort()).putShort(channels.toShort())
                header.putInt(rate).putInt(rate * channels * bits / 8).putShort((channels * bits / 8).toShort()).putShort(bits.toShort())
                header.put("data".toByteArray()).putInt(dataBytes.toInt())
                output.seek(0); output.write(header.array())
            }
            success = true
        } finally {
            runCatching { decoder?.stop() }
            runCatching { decoder?.release() }
            runCatching { extractor.release() }
            if (!success) destination.delete()
        }
    }
}
