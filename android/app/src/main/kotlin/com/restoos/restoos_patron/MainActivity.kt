package com.restoos.restoos_patron

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread
import kotlin.math.sqrt

/**
 * BARGE-IN VAD: asistan (TTS) konusurken mikrofonu VOICE_COMMUNICATION kaynagi +
 * AcousticEchoCanceler ile dinler. Bu, donanim yankı-engellemesini devreye sokar;
 * asistanin kendi sesi (echo) IPTAL edilir, mikrofonda sadece KULLANICI kalir.
 * Kullanici konusmaya baslayinca (RMS esigi ustunde) Flutter'a "voiceDetected" der.
 * Boylece Flutter TTS'i durdurup dinlemeye gecer (dokunmaya gerek kalmaz).
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var record: AudioRecord? = null
    private var aec: AcousticEchoCanceler? = null
    private var ns: NoiseSuppressor? = null
    private var agc: AutomaticGainControl? = null
    @Volatile private var calisiyor = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "resto/barge")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val esik = (call.argument<Int>("esik") ?: 1800)
                    val warmup = (call.argument<Int>("warmup") ?: 500)
                    basla(esik.toDouble(), warmup.toLong())
                    result.success(true)
                }
                "stop" -> { calisiyor = false; result.success(true) }
                else -> result.notImplemented()
            }
        }
    }

    private fun basla(esik: Double, warmupMs: Long) {
        if (calisiyor) return
        val sr = 16000
        val minBuf = AudioRecord.getMinBufferSize(sr, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        if (minBuf <= 0) return
        val bufSize = maxOf(minBuf, sr / 5 * 2) // ~200ms
        val rec = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                sr, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufSize
            )
        } catch (e: Exception) { null } ?: return
        if (rec.state != AudioRecord.STATE_INITIALIZED) { try { rec.release() } catch (_: Exception) {}; return }
        val sid = rec.audioSessionId
        try { if (AcousticEchoCanceler.isAvailable()) { aec = AcousticEchoCanceler.create(sid); aec?.enabled = true } } catch (_: Exception) {}
        try { if (NoiseSuppressor.isAvailable()) { ns = NoiseSuppressor.create(sid); ns?.enabled = true } } catch (_: Exception) {}
        try { if (AutomaticGainControl.isAvailable()) { agc = AutomaticGainControl.create(sid); agc?.enabled = true } } catch (_: Exception) {}
        record = rec
        calisiyor = true
        try { rec.startRecording() } catch (e: Exception) { temizle(); return }

        thread(start = true) {
            val frame = ShortArray(480) // 30ms @ 16k
            val t0 = System.currentTimeMillis()
            var ustuste = 0
            val gerekli = 2 // ~60ms sureli konusma (erken tetik -> ilk soruyu kacirma)
            while (calisiyor) {
                val n = try { rec.read(frame, 0, frame.size) } catch (e: Exception) { -1 }
                if (n <= 0) continue
                if (System.currentTimeMillis() - t0 < warmupMs) continue // AEC otursun
                var sum = 0.0
                for (i in 0 until n) { val s = frame[i].toDouble(); sum += s * s }
                val rms = sqrt(sum / n)
                if (rms > esik) ustuste++ else ustuste = 0
                if (ustuste >= gerekli) {
                    calisiyor = false
                    runOnUiThread { channel?.invokeMethod("voiceDetected", null) }
                    break
                }
            }
            temizle()
        }
    }

    private fun temizle() {
        try { record?.stop() } catch (_: Exception) {}
        try { record?.release() } catch (_: Exception) {}
        try { aec?.release() } catch (_: Exception) {}
        try { ns?.release() } catch (_: Exception) {}
        try { agc?.release() } catch (_: Exception) {}
        record = null; aec = null; ns = null; agc = null
    }

    override fun onDestroy() {
        calisiyor = false
        temizle()
        super.onDestroy()
    }
}
