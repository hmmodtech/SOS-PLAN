package com.ajami.sos.widget

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Read side of the widget bridge.
 *
 * The Flutter side (lib/services/widget_bridge.dart) writes a small JSON
 * snapshot after every change, so the widgets render instantly and safely
 * without ever touching the encrypted database or its key.
 *
 * Widget writes (ticking a task, adding a memo) go into a queue in
 * SharedPreferences and the Flutter side drains that queue into the database.
 */
object WidgetData {
  private const val PREFS = "FlutterSharedPreferences"
  private const val SNAPSHOT = "sos_widget.json"

  /** Queue keys, also read by Dart. */
  const val KEY_NOTES = "flutter.sos_widget_notes"
  const val KEY_TOGGLES = "flutter.sos_widget_toggles"

  // ---------- models ----------

  data class Task(
    val id: Int,
    val title: String,
    val subtitle: String,
    val done: Boolean,
    val priority: Int,
    val isPrivate: Boolean,
    val time: String?,
    val day: String = "",
  )

  data class Memo(val text: String, val day: String)

  data class Snapshot(
    val today: List<Task> = emptyList(),
    val overdue: List<Task> = emptyList(),
    val doneToday: Int = 0,
    val scheduledToday: Int = 0,
    val doneYesterday: Int = 0,
    val scheduledYesterday: Int = 0,
    val done7: Int = 0,
    val scheduled7: Int = 0,
    val memos: List<Memo> = emptyList(),
    val generatedAt: Long = 0,
    val hasAppData: Boolean = false,
  ) {
    val rateToday: Int
      get() = if (scheduledToday == 0) 0 else (doneToday * 100 / scheduledToday)
    val rate7: Int get() = if (scheduled7 == 0) 0 else (done7 * 100 / scheduled7)
    val left: Int get() = (scheduledToday - doneToday).coerceAtLeast(0)
  }

  // ---------- loading ----------

  fun load(context: Context): Snapshot {
    val file = snapshotFile(context) ?: return Snapshot()
    if (!file.exists() || file.length() < 2) return Snapshot()
    return try {
      parseSnapshot(JSONObject(file.readText()), file.lastModified())
    } catch (_: Throwable) {
      Snapshot()
    }
  }

  private fun snapshotFile(context: Context): File? {
    val ext = context.getExternalFilesDir(null)
    if (ext != null) {
      val f = File(ext, SNAPSHOT)
      if (f.exists()) return f
    }
    return File(context.filesDir, SNAPSHOT)
  }

  private fun parseSnapshot(o: JSONObject, modified: Long): Snapshot {
    fun tasks(key: String): List<Task> {
      val arr = o.optJSONArray(key) ?: return emptyList()
      return (0 until arr.length()).mapNotNull { i ->
        val t = arr.optJSONObject(i) ?: return@mapNotNull null
        Task(
          id = t.optInt("id"),
          title = t.optString("title"),
          subtitle = t.optString("subtitle"),
          done = t.optBoolean("done"),
          priority = t.optInt("priority"),
          isPrivate = t.optBoolean("private"),
          time = t.optString("time").takeIf { it.isNotEmpty() },
          day = t.optString("day"),
        )
      }
    }
    val memos = (o.optJSONArray("memos") ?: JSONArray()).let { arr ->
      (0 until arr.length()).mapNotNull { i ->
        val m = arr.optJSONObject(i) ?: return@mapNotNull null
        Memo(m.optString("text"), m.optString("day"))
      }
    }
    return Snapshot(
      today = tasks("today"),
      overdue = tasks("overdue"),
      doneToday = o.optInt("doneToday"),
      scheduledToday = o.optInt("scheduledToday"),
      doneYesterday = o.optInt("doneYesterday"),
      scheduledYesterday = o.optInt("scheduledYesterday"),
      done7 = o.optInt("done7"),
      scheduled7 = o.optInt("scheduled7"),
      memos = memos,
      generatedAt = o.optLong("generatedAt", modified),
      hasAppData = true,
    )
  }

  // ---------- queued widget actions ----------

  /** Marks a task ticked from the launcher, waiting for the app to apply it. */
  fun queueToggle(context: Context, taskId: Int, day: String) {
    if (taskId < 0 || day.isEmpty()) return
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val arr = JSONArray()
    // Collapse repeated taps on the same task/day to the final intent.
    var pendingDone: Boolean? = null
    val existing = pendingToggles(context)
    for (t in existing) {
      if (t.first == taskId && t.second == day) {
        pendingDone = !t.third
      } else {
        arr.put(JSONObject().put("id", t.first).put("day", t.second).put("done", t.third))
      }
    }
    // The snapshot's current value plus one flip decides the target state.
    val current = load(context).today.firstOrNull { it.id == taskId }?.done ?: false
    val target = pendingDone ?: !current
    arr.put(JSONObject().put("id", taskId).put("day", day).put("done", target))
    prefs.edit().putString(KEY_TOGGLES, arr.toString()).apply()
  }

  /** Triple of (taskId, day, done). */
  fun pendingToggles(context: Context): List<Triple<Int, String, Boolean>> {
    val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      .getString(KEY_TOGGLES, null) ?: return emptyList()
    return try {
      val arr = JSONArray(raw)
      (0 until arr.length()).mapNotNull { i ->
        val o = arr.optJSONObject(i) ?: return@mapNotNull null
        Triple(o.optInt("id"), o.optString("day"), o.optBoolean("done"))
      }
    } catch (_: Throwable) {
      emptyList()
    }
  }

  /** Memos typed in the widget sheet, newest first. */
  fun localMemos(context: Context): List<Memo> {
    val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      .getString(KEY_NOTES, null) ?: return emptyList()
    return try {
      val arr = JSONArray(raw)
      (0 until arr.length()).mapNotNull { i ->
        val o = arr.optJSONObject(i) ?: return@mapNotNull null
        Memo(o.optString("text"), o.optString("day"))
      }
    } catch (_: Throwable) {
      emptyList()
    }
  }

  fun saveLocalMemo(context: Context, text: String) {
    val clean = text.trim()
    if (clean.isEmpty()) return
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val arr = JSONArray()
    arr.put(JSONObject().put("text", clean).put("day", dayKey(0)))
    // Keep the last 20 queued memos.
    for (m in localMemos(context).take(19)) {
      arr.put(JSONObject().put("text", m.text).put("day", m.day))
    }
    prefs.edit().putString(KEY_NOTES, arr.toString()).apply()
  }

  fun clearLocalMemos(context: Context) {
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      .edit().remove(KEY_NOTES).apply()
  }

  // ---------- helpers ----------

  fun dayKey(offset: Int): String =
    SimpleDateFormat("yyyy-MM-dd", Locale.US).format(addDays(Date(), offset))

  private fun addDays(d: Date, n: Int): Date {
    val c = Calendar.getInstance().apply { time = d; add(Calendar.DAY_OF_YEAR, n) }
    return c.time
  }
}
