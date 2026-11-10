import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_state.dart';
import '../data/database.dart';
import '../data/models.dart';

/// يكتب لقطة صغيرة عن مهام اليوم والميمو والنتيجة، ويطلب من أندرويد تحديث
/// ودجت الشاشة الرئيسية.
///
/// الودجت يقرأ الملف فورًا (بدون مفتاح تشفير)، ويستطيع أيضًا قراءة قاعدة
/// البيانات المشفّرة مباشرة عند الحاجة — انظر WidgetData.kt.
class WidgetBridge {
  WidgetBridge._();

  static const _channel = MethodChannel('com.ajami.sos/widgets');
  static const _fileName = 'sos_widget.json';

  static bool _busy = false;
  static bool _again = false;

  /// يُستدعى بعد أي تغيير في المهام أو الميمو. لا يرمي استثناء أبدًا.
  static Future<void> sync() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _write();
      } while (_again);
      await _refresh();
    } catch (e) {
      logWidget('sync: $e');
    } finally {
      _busy = false;
    }
  }

  /// يقرأ الميمو المكتوبة من الودجت ويحفظها في قاعدة البيانات.
  static Future<int> pullWidgetMemos() async {
    try {
      final raw = await _channel.invokeMethod<String>('pullMemos');
      if (raw == null || raw.isEmpty) return 0;
      final list = jsonDecode(raw);
      if (list is! List) return 0;
      var added = 0;
      for (final item in list) {
        if (item is! Map) continue;
        final text = (item['text'] as String?)?.trim() ?? '';
        final day = (item['day'] as String?) ?? '';
        if (text.isEmpty) continue;
        final when = DateTime.tryParse(day) ?? DateTime.now();
        if (await _alreadySaved(text)) continue;
        await Db.instance.addNote(when, text);
        added++;
      }
      if (added > 0) {
        await _channel.invokeMethod<void>('clearMemos');
        await sync();
      }
      return added;
    } catch (e) {
      logWidget('pull: $e');
      return 0;
    }
  }

  static Future<bool> _alreadySaved(String text) async {
    final notes = await Db.instance.allNotes();
    return notes.any((n) => n.text == text);
  }

  static Future<void> _write() async {
    final dir = await _snapshotDir();
    if (dir == null) return;

    final tasks = await Db.instance.tasks();
    final done = await Db.instance.completionKeys();
    final today = dateOnly(DateTime.now());
    final ar = appState.isArabic;

    final todayList = tasks.where((t) => t.occursOn(today)).toList()
      ..sort((a, b) {
        final p = b.priority.compareTo(a.priority);
        if (p != 0) return p;
        final at = a.remindAt, bt = b.remindAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return at.compareTo(bt);
      });

    Map<String, Object?> asJson(Task t, DateTime day) {
      final id = t.id ?? -1;
      final items = t.checklist;
      var complete = 0;
      for (final c in items) {
        if (c.done) complete++;
      }
      return {
        'id': id,
        'title': t.title(ar),
        'subtitle': items.isEmpty ? '' : '$complete/${items.length}',
        'done': done.contains(doneKey(id, day)),
        'priority': t.priority,
        'private': t.isPrivate,
        'time': t.remindAt == null
            ? ''
            : '${t.remindAt!.hour.toString().padLeft(2, '0')}:'
                '${t.remindAt!.minute.toString().padLeft(2, '0')}',
      };
    }

    // مهام الأيام السابقة (غير المتكررة) التي لم تُنجز.
    final overdue = <Task>[];
    for (final t in tasks) {
      if (t.recurrence != 'none') continue;
      final d = dateOnly(t.date);
      if (!d.isBefore(today)) continue;
      final id = t.id;
      if (id == null) continue;
      if (done.contains(doneKey(id, d))) continue;
      overdue.add(t);
    }
    overdue.sort((a, b) => b.priority.compareTo(a.priority));

    int scheduledOn(DateTime day) =>
        tasks.where((t) => t.occursOn(day)).length;
    int doneOn(DateTime day) {
      var n = 0;
      for (final t in tasks) {
        final id = t.id;
        if (id == null || !t.occursOn(day)) continue;
        if (done.contains(doneKey(id, day))) n++;
      }
      return n;
    }

    final yesterday = DateTime(today.year, today.month, today.day - 1);
    var scheduled7 = 0;
    var done7 = 0;
    for (var i = 0; i < 7; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      scheduled7 += scheduledOn(d);
      done7 += doneOn(d);
    }

    final memos = await Db.instance.notesOn(today);

    final data = <String, Object?>{
      'generatedAt': DateTime.now().millisecondsSinceEpoch,
      'today': [for (final t in todayList) asJson(t, today)],
      'overdue': [
        for (final t in overdue.take(5))
          if (t.id != null) asJson(t, dateOnly(t.date)),
      ],
      'scheduledToday': scheduledOn(today),
      'doneToday': doneOn(today),
      'scheduledYesterday': scheduledOn(yesterday),
      'doneYesterday': doneOn(yesterday),
      'scheduled7': scheduled7,
      'done7': done7,
      'memos': [
        for (final n in memos.reversed.take(5))
          {'text': n.text, 'day': dayKey(n.day)},
      ],
    };

    final file = File('${dir.path}/$_fileName');
    await file.writeAsString(jsonEncode(data), flush: true);
  }

  /// نفس المجلد الذي يقرأه WidgetData.kt:
  /// getExternalFilesDir(null) أولًا ثم مجلد التطبيق الداخلي.
  static Future<Directory?> _snapshotDir() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    } catch (_) {}
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _refresh() async {
    try {
      await _channel.invokeMethod<void>('refresh');
    } on MissingPluginException {
      // ليس أندرويد، أو الودجت غير مثبّت: لا مشكلة.
    } catch (e) {
      logWidget('refresh: $e');
    }
  }

  /// يستمع لأوامر الودجت: فتح نموذج مهمة جديدة، أو سحب الميمو المكتوبة.
  static void listen({
    required Future<void> Function() onNewTask,
    required Future<void> Function() onMemos,
  }) {
    _channel.setMethodCallHandler((call) async {
      try {
        if (call.method == 'openAction') {
          final action = call.arguments as String?;
          if (action == 'new_task') await onNewTask();
          if (action == 'pull_memos') await onMemos();
        }
      } catch (e) {
        logWidget('action: $e');
      }
    });
  }
}

/// أخطاء الودجت تُسجّل ولا تُعطّل التطبيق أبدًا.
void logWidget(String message) {
  if (kDebugMode) debugPrint('widgets: $message');
}
