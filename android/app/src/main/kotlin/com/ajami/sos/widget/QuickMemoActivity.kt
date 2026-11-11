package com.ajami.sos.widget

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import com.ajami.sos.MainActivity
import com.ajami.sos.R

/**
 * Small translucent sheet used by the memo widget.
 *
 * EditText is not permitted inside RemoteViews, so the widget's fake input box
 * opens this activity: type, tap Save, and the memo is queued + shown instantly
 * without leaving the home screen.
 */
class QuickMemoActivity : Activity() {

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContentView(R.layout.activity_quick_memo)

    // A floating card instead of a full screen.
    window.setLayout(
      WindowManager.LayoutParams.MATCH_PARENT,
      WindowManager.LayoutParams.WRAP_CONTENT,
    )
    window.setGravity(Gravity.BOTTOM)
    window.setBackgroundDrawableResource(android.R.color.transparent)
    window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)

    val input = findViewById<EditText>(R.id.memo_input)
    input.requestFocus()

    findViewById<Button>(R.id.memo_cancel).setOnClickListener { finish() }

    findViewById<Button>(R.id.memo_save).setOnClickListener {
      val text = input.text?.toString()?.trim().orEmpty()
      if (text.isNotEmpty()) {
        WidgetData.saveLocalMemo(this, text)
        // Push it to the app so it lands in the encrypted database right away.
        try {
          startActivity(
            Intent(this, MainActivity::class.java).apply {
              action = "com.ajami.sos.PULL_MEMOS"
              flags = Intent.FLAG_ACTIVITY_NEW_TASK
            },
          )
        } catch (_: Throwable) {
          // App closed: the queue is drained on next launch.
        }
      }
      MemoWidgetProvider.refresh(this)
      finish()
    }
  }
}
