package com.ajami.sos

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import com.ajami.sos.widget.WidgetActions
import com.ajami.sos.widget.WidgetData
import com.ajami.sos.widget.WidgetKeys
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by local_auth (biometric prompt).
class MainActivity : FlutterFragmentActivity() {

    private var channel: MethodChannel? = null
    private var pendingAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Blocks screenshots and blank recent-app thumbnails.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        pendingAction = actionFrom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = actionFrom(intent)
        if (action != null) dispatch(action)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ajami.sos/widgets"
        )
        channel = ch

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                // Ask every home-screen widget to redraw.
                "refresh" -> {
                    WidgetActions.refreshAll(this)
                    result.success(null)
                }
                // Memos typed in the widget, waiting to be stored in the DB.
                "pullMemos" -> {
                    val memos = WidgetData.localMemos(this)
                    val json = org.json.JSONArray().apply {
                        for (m in memos) {
                            put(org.json.JSONObject().put("text", m.text).put("day", m.day))
                        }
                    }
                    result.success(json.toString())
                }
                "clearMemos" -> {
                    WidgetData.clearLocalMemos(this)
                    WidgetActions.refreshAll(this)
                    result.success(null)
                }
                // Checkbox taps queued from the tasks widget.
                "pullToggles" -> {
                    val arr = org.json.JSONArray()
                    for (t in WidgetData.pendingToggles(this)) {
                        arr.put(
                            org.json.JSONObject()
                                .put("id", t.first)
                                .put("day", t.second)
                                .put("done", t.third)
                        )
                    }
                    result.success(arr.toString())
                }
                "clearToggles" -> {
                    getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                        .edit().remove(WidgetData.KEY_TOGGLES).apply()
                    WidgetActions.refreshAll(this)
                    result.success(null)
                }
                // Which screen the user asked for by tapping a widget.
                "consumeAction" -> {
                    val action = pendingAction
                    pendingAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }

        // Hand over an action that arrived before the engine was ready.
        pendingAction?.let { dispatch(it) }
    }

    private fun actionFrom(intent: Intent?): String? = when (intent?.action) {
        "com.ajami.sos.NEW_TASK" -> "new_task"
        "com.ajami.sos.PULL_MEMOS" -> "pull_memos"
        else -> null
    }

    private fun dispatch(action: String) {
        channel?.invokeMethod("openAction", action)
    }
}
