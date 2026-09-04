package io.lovetap.desk

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews

/**
 * The third ambient surface: the other person on the home screen, without opening anything.
 *
 * It holds one line — the same line the standing notification carries — on the same desk colour
 * the app uses, so the widget is a piece of the same room rather than a separate product. It shows
 * no counts, no unread anything, and nothing that can be fallen behind on.
 *
 * The line is written by the app and kept here, so the widget survives a reboot with the last true
 * thing rather than going blank or, worse, showing something stale as if it were current.
 */
class Widget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        draw(context, manager, ids, prefs.getString(KEY_WHO, "") ?: "", prefs.getString(KEY_LINE, "") ?: "")
    }

    companion object {
        private const val PREFS = "ambient"
        private const val KEY_WHO = "who"
        private const val KEY_LINE = "line"

        fun refresh(context: Context, who: String, line: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_WHO, who).putString(KEY_LINE, line).apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, Widget::class.java))
            if (ids.isNotEmpty()) draw(context, manager, ids, who, line)
        }

        private fun draw(context: Context, manager: AppWidgetManager, ids: IntArray, who: String, line: String) {
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_IMMUTABLE,
            )
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.widget_partner)
                views.setTextViewText(R.id.widget_who, who)
                views.setTextViewText(R.id.widget_line, if (line.isEmpty()) "nothing since you last looked" else line)
                views.setOnClickPendingIntent(R.id.widget_root, open)
                manager.updateAppWidget(id, views)
            }
        }
    }
}
