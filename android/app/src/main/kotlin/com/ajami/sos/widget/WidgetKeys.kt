package com.ajami.sos.widget

/** Shared action names used by both the widgets and MainActivity. */
object WidgetKeys {
  const val ACTION_TOGGLE = "com.ajami.sos.widget.TOGGLE"
  const val ACTION_ADD_MEMO = "com.ajami.sos.widget.ADD_MEMO"
  const val ACTION_REFRESH = "com.ajami.sos.widget.REFRESH"

  const val EXTRA_TASK_ID = "task_id"
  const val EXTRA_DAY = "day"
  const val EXTRA_TEXT = "text"
  const val EXTRA_WIDGET_ID = "widget_id"

  /** Widget ids for AppWidgetManager updates. */
  const val REQ_LIST = 1001
  const val REQ_MEMO = 1002
  const val REQ_RESULT = 1003
}
