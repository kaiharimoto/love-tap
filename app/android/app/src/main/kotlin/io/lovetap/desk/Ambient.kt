package io.lovetap.desk

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The two ambient surfaces the phone itself provides.
 *
 * The standing line is an ongoing, silent, low-priority notification carrying one sentence about
 * the other person. It is deliberately not a message preview and deliberately not a count: it says
 * what they are, not how much is owed. It replaces itself rather than stacking, so there is never
 * a pile to clear and nothing to feel behind on.
 *
 * The pocket is the same feeling the app plays when it is open, played when it is not: the
 * feeling's own waveform through the vibrator, with a heads-up notification carrying its name.
 *
 * Both live on their own channels so either can be turned off in the phone's own settings without
 * turning off the other, which is a thing a person should be able to do without asking the app.
 */
object Ambient {
    private const val STANDING_CHANNEL = "standing"
    private const val ARRIVAL_CHANNEL = "arrivals"
    private const val STANDING_ID = 1
    private const val ARRIVAL_ID = 2
    private const val ASK_CODE = 8401

    fun attach(activity: Activity, engine: FlutterEngine) {
        ensureChannels(activity)
        MethodChannel(engine.dartExecutor.binaryMessenger, "io.lovetap/ambient").setMethodCallHandler { call, result ->
            when (call.method) {
                "allowed" -> result.success(allowed(activity))
                "ask" -> {
                    ask(activity)
                    result.success(allowed(activity))
                }
                "standing" -> {
                    standing(activity, call.argument<String>("who") ?: "", call.argument<String>("line") ?: "")
                    result.success(null)
                }
                "pocket" -> {
                    val timings = (call.argument<List<Int>>("timings") ?: emptyList()).map { it.toLong() }.toLongArray()
                    val amplitudes = (call.argument<List<Int>>("amplitudes") ?: emptyList()).toIntArray()
                    Haptics.play(activity, timings, amplitudes)
                    arrival(activity, call.argument<String>("name") ?: "")
                    result.success(null)
                }
                "clear" -> {
                    manager(activity).cancel(STANDING_ID)
                    manager(activity).cancel(ARRIVAL_ID)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val standing = NotificationChannel(STANDING_CHANNEL, "where they are", NotificationManager.IMPORTANCE_LOW)
        standing.description = "One line about them, always there, never a count."
        standing.setShowBadge(false)
        standing.enableVibration(false)
        val arrivals = NotificationChannel(ARRIVAL_CHANNEL, "when something lands", NotificationManager.IMPORTANCE_HIGH)
        arrivals.description = "A feeling, a note, a picture. The rhythm is the feeling's own."
        arrivals.setShowBadge(false)
        // the app plays the waveform itself so that the pressure is the feeling's, not the system's
        arrivals.enableVibration(false)
        manager(context).createNotificationChannels(listOf(standing, arrivals))
    }

    private fun allowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return manager(context).areNotificationsEnabled()
        return ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun ask(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        ActivityCompat.requestPermissions(activity, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), ASK_CODE)
    }

    private fun open(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        return PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
    }

    fun standing(context: Context, who: String, line: String) {
        if (!allowed(context)) return
        val n = NotificationCompat.Builder(context, STANDING_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(who)
            .setContentText(line)
            .setStyle(NotificationCompat.BigTextStyle().bigText(line))
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_STATUS)
            .setContentIntent(open(context))
            .build()
        manager(context).notify(STANDING_ID, n)
        Widget.refresh(context, who, line)
    }

    fun arrival(context: Context, name: String) {
        if (!allowed(context)) return
        val n = NotificationCompat.Builder(context, ARRIVAL_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(name)
            .setContentText("held out to you")
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setContentIntent(open(context))
            .build()
        manager(context).notify(ARRIVAL_ID, n)
    }
}
