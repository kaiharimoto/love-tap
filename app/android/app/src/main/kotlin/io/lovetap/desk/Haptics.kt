package io.lovetap.desk

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The vibrator, driven by the same notation the app writes a feeling in.
 *
 * docs/FEELINGS.md gives every feeling a rhythm as `on@amp offN ×N`; the Dart side turns that into
 * a pair of arrays and this plays them. The point of using createWaveform rather than a canned
 * effect is that the amplitudes matter: two feelings with the same timing and different pressure
 * are two different feelings, and they have to be told apart with the screen face down.
 */
object Haptics {
    fun attach(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "lovetap/haptics").setMethodCallHandler { call, result ->
            when (call.method) {
                "waveform" -> {
                    val timings = (call.argument<List<Int>>("timings") ?: emptyList()).map { it.toLong() }.toLongArray()
                    val amplitudes = (call.argument<List<Int>>("amplitudes") ?: emptyList()).toIntArray()
                    play(context, timings, amplitudes)
                    result.success(null)
                }
                "supported" -> result.success(vibrator(context)?.hasAmplitudeControl() == true)
                else -> result.notImplemented()
            }
        }
    }

    fun vibrator(context: Context): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    fun play(context: Context, timings: LongArray, amplitudes: IntArray) {
        if (timings.isEmpty()) return
        val v = vibrator(context) ?: return
        val amps = if (amplitudes.size == timings.size) {
            amplitudes.map { it.coerceIn(0, 255) }.toIntArray()
        } else {
            IntArray(timings.size) { if (it % 2 == 0) 0 else 180 }
        }
        if (v.hasAmplitudeControl()) {
            v.vibrate(VibrationEffect.createWaveform(timings, amps, -1))
        } else {
            // no pressure to work with: the rhythm alone still has to be recognisable
            v.vibrate(VibrationEffect.createWaveform(timings, -1))
        }
    }
}
