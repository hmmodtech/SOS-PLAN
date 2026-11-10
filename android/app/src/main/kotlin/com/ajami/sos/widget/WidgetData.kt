package com.ajami.sos.widget

import android.content.Context
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import net.sqlcipher.database.SQLiteDatabase as CipherDatabase

/**
 * Read-only access to the app's data for the home-screen widgets.
 *
 * The Flutter app stores everything in an SQLCipher database
 * (`sos_secure.db`) whose password lives in flutter_secure_storage, and the
 * scheduler keeps its own plain JSON snapshot (`sos_widget.json`) on every
 * change. We read the snapshot first because it needs no key, and fall back to
 * the encrypted database (same key derivation as flutter_secure_storage) so the
 * widgets still work if the snapshot was never written.
 */
object WidgetData {
  private const val PREFS = "FlutterSharedPreferences"
  private const val SNAPSHOT = "sos_widget.json"
  const val databaseName = "sos_secure.db"

  const val KEY_NOTES = "flutter.sos_widget_notes"

  // ---------- public model ----------

  data class Task(
    val id: Int,
    val title: String,
    val subtitle: String,
    val done: Boolean,
    val priority: Int,
    val isPrivate: Boolean,
    val time: String?,
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
  ) {
    val rateToday: Int
      get() = if (scheduledToday == 0) 0 else (doneToday * 100 / scheduledToday)
    val rate7: Int
      get() = if (scheduled7 == 0) 0 else (done7 * 100 / scheduled7)
    val left: Int get() = (scheduledToday - doneToday).coerceAtLeast(0)
  }

  fun isArabic(context: Context): Boolean {
    val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    return p.getBoolean("flutter.ar", false)
  }

  // ---------- loading ----------

  fun load(context: Context): Snapshot {
    snapshotFile(context)?.let { file ->
      try {
        if (file.exists() && file.length() > 2) {
          return parseSnapshot(JSONObject(file.readText()))
        }
      } catch (_: Throwable) {
        // Corrupt snapshot: rebuild from the database below.
      }
    }
    return fromDatabase(context)
  }

  private fun snapshotFile(context: Context): File? =
    context.getExternalFilesDir(null)?.let { File(it, SNAPSHOT) }
      ?: File(context.filesDir, SNAPSHOT)

  private fun parseSnapshot(o: JSONObject): Snapshot {
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
      generatedAt = o.optLong("generatedAt"),
    )
  }

  private class Row(val task: Task, val date: String, val recurrence: String,
                    val remindAt: String?, val checklist: JSONArray?)

  /** Reads the encrypted database directly, mirroring lib/data/database.dart. */
  private fun fromDatabase(context: Context): Snapshot {
    // The SQLCipher build used by sqflite_sqlcipher ships as libsqlcipher.so.
    try {
      CipherDatabase.loadLibs(context)
    } catch (_: Throwable) {
      // loadLibs is only needed once; failures fall through to the plain API.
    }
    val dir = context.getDatabasePath(databaseName).parentFile ?: return Snapshot()
    val file = File(dir, databaseName)
    if (!file.exists()) return Snapshot()

    val key = secureStorageKey(context) ?: return Snapshot()
    var db: SQLiteDatabase? = null
    try {
      db = CipherDatabase.openDatabase(file.absolutePath, key, null,
        SQLiteDatabase.OPEN_READONLY)
      val tasks = mutableListOf<Row>()
      db.rawQuery(
        "SELECT id,title_en,title_ar,date,remind_at,category,priority," +
          "is_private,recurrence,checklist FROM tasks", null,
      ).use { c ->
        while (c.moveToNext()) {
          val ar = isArabic(context)
          val titleEn = c.getString(1) ?: ""
          val titleAr = c.getString(2) ?: ""
          val checklist = c.getString(9)?.let {
            try { JSONArray(it) } catch (_: Throwable) { null }
          }
          val detail = checklist?.optJSONObject(0)?.optString("t").orEmpty()
          tasks += Row(
            Task(
              id = c.getInt(0),
              title = if (ar && titleAr.isNotEmpty()) titleAr else titleEn,
              subtitle = detail,
              done = false,
              priority = c.getInt(6),
              isPrivate = c.getInt(7) == 1,
              time = null,
            ),
            date = c.getString(3) ?: "",
            recurrence = c.getString(8) ?: "none",
            remindAt = c.getString(4),
            checklist = checklist,
          )
        }
      }

      val doneKeys = mutableSetOf<String>()
      db.rawQuery("SELECT task_id,day FROM completions", null).use { c ->
        while (c.moveToNext()) doneKeys += "${c.getInt(0)}|${c.getString(1)}"
      }

      return build(tasks, doneKeys)
    } catch (_: Throwable) {
      return Snapshot()
    } finally {
      try { db?.close() } catch (_: Throwable) {}
    }
  }

  private fun build(rows: List<Row>, doneKeys: Set<String>): Snapshot {
    val today = dayKey(0)
    val yesterday = dayKey(-1)

    fun occursOn(row: Row, day: Date): Boolean {
      val start = parseDay(row.date) ?: return false
      val d = truncate(day)
      if (d.before(start)) return false
      return when (row.recurrence) {
        "daily" -> true
        "weekly" -> dayOfWeek(d) == dayOfWeek(start)
        "monthly" -> dayOfMonth(d) == dayOfMonth(start)
        else -> d == start
      }
    }

    fun isDone(row: Row, key: String) = doneKeys.contains("${row.task.id}|$key")

    val todayList = mutableListOf<Task>()
    val overdueList = mutableListOf<Task>()
    var scheduledToday = 0
    var doneToday = 0
    var scheduledY = 0
    var doneY = 0

    val now = Date()
    for (row in rows) {
      if (occursOn(row, now)) {
        scheduledToday++
        val done = isDone(row, today)
        if (done) doneToday++
        todayList += decorate(row, done)
      }
      val y = addDays(now, -1)
      if (occursOn(row, y)) {
        scheduledY++
        if (isDone(row, yesterday)) doneY++
      }
      // One-off tasks from previous days that were never completed.
      if (row.recurrence == "none") {
        val start = parseDay(row.date)
        if (start != null && start.before(truncate(now)) && !doneKeys.any {
            it.startsWith("${row.task.id}|")
          }) {
          overdueList += decorate(row, false)
        }
      }
    }

    todayList.sortWith(compareByDescending<Task> { it.priority }.thenBy { it.time ?: "99:99" })
    overdueList.sortByDescending { it.priority }

    var scheduled7 = 0
    var done7 = 0
    for (d in 0..6) {
      val day = addDays(now, -d)
      val key = dayKey(-d)
      for (row in rows) {
        if (!occursOn(row, day)) continue
        scheduled7++
        if (isDone(row, key)) done7++
      }
    }

    return Snapshot(
      today = todayList,
      overdue = overdueList.take(5),
      doneToday = doneToday,
      scheduledToday = scheduledToday,
      doneYesterday = doneY,
      scheduledYesterday = scheduledY,
      done7 = done7,
      scheduled7 = scheduled7,
      memos = localMemos(),
      generatedAt = System.currentTimeMillis(),
    )
  }

  private fun decorate(row: Row, done: Boolean): Task {
    val sub = row.checklist?.let { arr ->
      if (arr.length() == 0) "" else {
        var d = 0
        for (i in 0 until arr.length()) {
          if (arr.optJSONObject(i)?.optBoolean("d") == true) d++
        }
        "$d/${arr.length()}"
      }
    }.orEmpty()
    return row.task.copy(done = done, subtitle = sub, time = timeOf(row.remindAt))
  }

  /** Memos typed straight into the widget (the DB stays the single owner). */
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
    if (text.isBlank()) return
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val arr = JSONArray()
    val entry = JSONObject().put("text", text.trim()).put("day", dayKey(0))
    arr.put(entry)
    // Keep the last 20 memos only.
    val existing = localMemos(context)
    for (m in existing.take(19)) {
      arr.put(JSONObject().put("text", m.text).put("day", m.day))
    }
    prefs.edit().putString(KEY_NOTES, arr.toString()).apply()
  }

  fun clearLocalMemos(context: Context) {
    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      .edit().remove(KEY_NOTES).apply()
  }

  // ---------- flutter_secure_storage key derivation ----------

  /**
   * flutter_secure_storage v9 on Android encrypts values with an AES key stored
   * in the Android Keystore under key "flutter_secure_storage_key", and the
   * ciphertext is base64(iv):base64(cipher). This mirrors
   * SecureStorageCipher.decrypt so we can recover the SQLCipher password.
   */
  fun secureKey(context: Context): String? = secureStorageKey(context)

  private fun secureStorageKey(context: Context): String? {
    val prefs = context.getSharedPreferences(
      "FlutterSecureStorage", Context.MODE_PRIVATE,
    )
    val raw = prefs.getString("sos_db_key", null) ?: return null
    return try {
      val parts = raw.split(":")
      if (parts.size != 2) return raw
      val iv = android.util.Base64.decode(parts[0], android.util.Base64.DEFAULT)
      val data = android.util.Base64.decode(parts[1], android.util.Base64.DEFAULT)

      val keystore = java.security.KeyStore.getInstance("AndroidKeyStore")
      keystore.load(null)
      val secretKey = keystore.getKey("flutter_secure_storage_key", null)
        as? javax.crypto.SecretKey ?: return null
      val cipher = javax.crypto.Cipher.getInstance("AES/CBC/PKCS7Padding")
      cipher.init(
        javax.crypto.Cipher.DECRYPT_MODE, secretKey,
        javax.crypto.spec.IvParameterSpec(iv),
      )
      String(cipher.doFinal(data), Charsets.UTF_8)
    } catch (_: Throwable) {
      null
    }
  }

  // ---------- small helpers ----------

  private fun timeOf(iso: String?): String? {
    if (iso.isNullOrEmpty()) return null
    return try {
      val d = SimpleDateFormat("yyyy-MM-dd'T'HH:mm", Locale.US).parse(iso.take(16))
      SimpleDateFormat("HH:mm", Locale.US).format(d!!)
    } catch (_: Throwable) {
      null
    }
  }

  fun parseDay(s: String): Date? = try {
    truncate(SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(s.take(10))!!)
  } catch (_: Throwable) {
    null
  }

  private fun truncate(d: Date): Date {
    val c = Calendar.getInstance().apply {
      time = d
      set(Calendar.HOUR_OF_DAY, 0)
      set(Calendar.MINUTE, 0)
      set(Calendar.SECOND, 0)
      set(Calendar.MILLISECOND, 0)
    }
    return c.time
  }

  private fun addDays(d: Date, n: Int): Date {
    val c = Calendar.getInstance().apply { time = d; add(Calendar.DAY_OF_YEAR, n) }
    return c.time
  }

  fun dayKey(offset: Int): String =
    SimpleDateFormat("yyyy-MM-dd", Locale.US).format(addDays(Date(), offset))

  private fun dayOfWeek(d: Date): Int {
    val c = Calendar.getInstance().apply { time = d }
    return c.get(Calendar.DAY_OF_WEEK)
  }

  private fun dayOfMonth(d: Date): Int {
    val c = Calendar.getInstance().apply { time = d }
    return c.get(Calendar.DAY_OF_MONTH)
  }
}
