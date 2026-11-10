package com.ajami.sos.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import net.sqlcipher.database.SQLiteDatabase as CipherDatabase

/**
 * Write side of the widget bridge.
 *
 * The widget cannot ask Dart to toggle a checkbox while the app is closed, so
 * the completion row is written straight into the encrypted database with the
 * same key the app uses, then all widgets are refreshed.
 */
object WidgetActions {

  /** Marks a task done/undone for one day, mirroring Db.setDone in Dart. */
  fun toggleTask(context: Context, taskId: Int, day: String) {
    val db = openWritable(context) ?: return
    try {
      val done = db.rawQuery(
        "SELECT 1 FROM completions WHERE task_id=? AND day=?",
        arrayOf(taskId.toString(), day),
      ).use { it.moveToFirst() }

      if (done) {
        db.execSQL(
          "DELETE FROM completions WHERE task_id=? AND day=?",
          arrayOf(taskId.toString(), day),
        )
      } else {
        db.execSQL(
          "INSERT OR IGNORE INTO completions(task_id,day) VALUES(?,?)",
          arrayOf(taskId.toString(), day),
        )
      }
    } catch (_: Throwable) {
      // A failed toggle must never crash the launcher.
    } finally {
      try { db.close() } catch (_: Throwable) {}
    }
  }

  private fun openWritable(context: Context): SQLiteDatabase? {
    try { CipherDatabase.loadLibs(context) } catch (_: Throwable) {}
    val file = File(
      context.getDatabasePath(WidgetData.databaseName).parentFile,
      WidgetData.databaseName,
    )
    if (!file.exists()) return null
    val key = WidgetData.secureKey(context) ?: return null
    return try {
      CipherDatabase.openDatabase(
        file.absolutePath, key, null, SQLiteDatabase.OPEN_READWRITE,
      )
    } catch (_: Throwable) {
      null
    }
  }

  /** Updates every widget after data changed. */
  fun refreshAll(context: Context) {
    TasksWidgetProvider.refresh(context)
    MemoWidgetProvider.refresh(context)
    ResultWidgetProvider.refresh(context)
  }
}
