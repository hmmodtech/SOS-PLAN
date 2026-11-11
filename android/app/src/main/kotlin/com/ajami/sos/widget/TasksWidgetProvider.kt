package com.ajami.sos.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RemoteViews
import android.widget.TextView
import com.ajami.sos.MainActivity
import com.ajami.sos.R

/**
 * Home-screen to-do widget.
 *
 * Each row is checkable without opening the app; tapping the title opens the
 * task in the app, and the + button opens the new-task form.
 */
class TasksWidgetProvider : AppWidgetProvider() {

  override fun onUpdate(
    context: Context,
    manager: AppWidgetManager,
    ids: IntArray,
  ) {
    for (id in ids) manager.updateAppWidget(id, build(context))
  }

  override fun onReceive(context: Context, intent: Intent) {
    super.onReceive(context, intent)
    if (intent.action == WidgetKeys.ACTION_TOGGLE) {
      val taskId = intent.getIntExtra(WidgetKeys.EXTRA_TASK_ID, -1)
      val day = intent.getStringExtra(WidgetKeys.EXTRA_DAY).orEmpty()
      if (taskId >= 0 && day.isNotEmpty()) {
        WidgetActions.toggleTask(context, taskId, day)
      }
      refresh(context)
    }
  }

  companion object {
    /** Muted gray-blue for finished tasks, bright text otherwise. */
    private const val DONE_TEXT = 0xFF7C8FAB.toInt()
    private const val ACTIVE_TEXT = 0xFFD7E6F5.toInt()

    fun refresh(context: Context) {
      val manager = AppWidgetManager.getInstance(context)
      val ids = manager.getAppWidgetIds(
        ComponentName(context, TasksWidgetProvider::class.java),
      )
      if (ids.isEmpty()) return
      val views = build(context)
      for (id in ids) manager.updateAppWidget(id, views)
    }

    fun build(context: Context): RemoteViews {
      val views = RemoteViews(context.packageName, R.layout.widget_tasks)
      val data = WidgetData.load(context)
      val res = context.resources

      views.removeAllViews(R.id.w_rows)

      val tasks = data.today.take(4)
      if (tasks.isEmpty()) {
        views.setViewVisibility(R.id.w_empty, View.VISIBLE)
      } else {
        views.setViewVisibility(R.id.w_empty, View.GONE)
      }

      val todayKey = WidgetData.dayKey(0)
      for (task in tasks) {
        val row = RemoteViews(context.packageName, R.layout.widget_tasks_row)
        row.setTextViewText(R.id.row_title, task.title)
        row.setImageViewResource(
          R.id.row_check,
          if (task.done) R.drawable.widget_check_on
          else R.drawable.widget_check_off,
        )
        // setInt uses reflection and is unnecessary here: the row reports its
        // state through a tinted title and the checkbox artwork instead.
        row.setTextColor(
          R.id.row_title,
          if (task.done) DONE_TEXT else ACTIVE_TEXT,
        )
        row.setViewVisibility(
          R.id.row_strike,
          if (task.done) android.view.View.VISIBLE else android.view.View.GONE,
        )

        val sub = buildString {
          if (!task.time.isNullOrEmpty()) append(task.time)
          if (task.subtitle.isNotEmpty()) {
            if (isNotEmpty()) append("  ")
            append("☑ ")
            append(task.subtitle)
          }
          if (task.isPrivate) {
            if (isNotEmpty()) append("  ")
            append("🔒")
          }
        }
        if (sub.isNotEmpty()) {
          row.setViewVisibility(R.id.row_sub, View.VISIBLE)
          row.setTextViewText(R.id.row_sub, sub)
        } else {
          row.setViewVisibility(R.id.row_sub, View.GONE)
        }

        if (task.priority >= 2) {
          row.setViewVisibility(R.id.row_tag, View.VISIBLE)
          row.setTextViewText(R.id.row_tag, "●")
        } else {
          row.setViewVisibility(R.id.row_tag, View.GONE)
        }

        // Tap the row: open the app.
        row.setOnClickPendingIntent(R.id.row_title, openApp(context))
        // Tap the checkbox: toggle without leaving the launcher.
        row.setOnClickPendingIntent(
          R.id.row_check,
          toggleIntent(context, task.id, task.day.ifEmpty { todayKey }),
        )
        views.addView(R.id.w_rows, row)
      }

      val left = data.left
      views.setTextViewText(
        R.id.w_count,
        res.getString(R.string.widget_done_of) + " " +
          "${data.doneToday}/${data.scheduledToday}" +
          if (left > 0) "  ·  $left " + res.getString(R.string.widget_left) else "",
      )

      views.setOnClickPendingIntent(R.id.w_add, newTaskIntent(context))
      return views
    }

    private fun openApp(context: Context): PendingIntent {
      val intent = Intent(context, MainActivity::class.java).apply {
        action = Intent.ACTION_MAIN
        addCategory(Intent.CATEGORY_LAUNCHER)
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      }
      return PendingIntent.getActivity(
        context, WidgetKeys.REQ_LIST, intent, pendingFlags(),
      )
    }

    private fun newTaskIntent(context: Context): PendingIntent {
      val intent = Intent(context, MainActivity::class.java).apply {
        action = "com.ajami.sos.NEW_TASK"
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      }
      return PendingIntent.getActivity(
        context, WidgetKeys.REQ_LIST + 1, intent, pendingFlags(),
      )
    }

    private fun toggleIntent(
      context: Context,
      taskId: Int,
      day: String,
    ): PendingIntent {
      val intent = Intent(context, TasksWidgetProvider::class.java).apply {
        action = WidgetKeys.ACTION_TOGGLE
        putExtra(WidgetKeys.EXTRA_TASK_ID, taskId)
        putExtra(WidgetKeys.EXTRA_DAY, day)
      }
      return PendingIntent.getBroadcast(
        context, taskId, intent, pendingFlags(),
      )
    }

    private fun pendingFlags(): Int =
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
  }
}
