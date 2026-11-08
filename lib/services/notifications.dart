```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/app_state.dart';
import '../data/database.dart';
import '../data/models.dart';

class Bell {
  Bell._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _digestId = 999001;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'sos_tasks',
      'Task reminders',
      channelDescription: 'Bell reminders for SOS tasks',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  /// يجدول الجرس لأقرب موعد قادم. المتكرر يستخدم matchDateTimeComponents فيتكرر تلقائياً.
  static Future<void> schedule(Task t, int id,
      {required bool enabled, bool done = false}) async {
    await _plugin.cancel(id);
    if (!enabled || t.remindAt == null) return;
    if (done && t.recurrence == 'none') return;

    final now = DateTime.now();
    DateTime? first;
    for (var i = 0; i < 400 && first == null; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final at = t.bellOn(day)!;
      if (at.isAfter(now) && t.occursOn(day)) first = at;
    }
    if (first == null) return;

    final match = switch (t.recurrence) {
      'daily' => DateTimeComponents.time,
      'weekly' => DateTimeComponents.dayOfWeekAndTime,
      'monthly' => DateTimeComponents.dayOfMonthAndTime,
      _ => null,
    };
    final body = t.details(appState.isArabic);

    await _plugin.zonedSchedule(
      id,
      t.title(appState.isArabic),
      body.isEmpty ? null : body,
      tz.TZDateTime.from(first, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: match,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);

  static Future<void> digest({required bool enabled}) async {
    await _plugin.cancel(_digestId);
    if (!enabled) return;
    final now = DateTime.now();
    final at = DateTime(now.year, now.month, now.day, 7, 30);
    final first = at.isAfter(now)
        ? at
        : DateTime(now.year, now.month, now.day + 1, 7, 30);
    await _plugin.zonedSchedule(
      _digestId,
      appState.t('Mission briefing', 'إحاطة المهام'),
      appState.t("Open the app to review today's tasks.",
          'افتح التطبيق لمراجعة مهام اليوم.'),
      tz.TZDateTime.from(first, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> test() => _plugin.show(
        0,
        appState.t('Bell test', 'اختبار الجرس'),
        appState.t('Notifications are working.', 'التنبيهات تعمل بنجاح.'),
        _details,
      );

  /// يعيد جدولة كل التنبيهات (بعد إعادة التشغيل، أو تغيير الإعدادات، أو الاستعادة)
  static Future<void> resyncAll() async {
    final db = Db.instance;
    final tasks = await db.tasks();
    final done = await db.completionKeys();
    for (final t in tasks) {
      await schedule(
        t,
        t.id!,
        enabled: appState.notificationsOn,
        done: done.contains(doneKey(t.id!, t.date)),
      );
    }
    await digest(enabled: appState.notificationsOn && appState.morningBriefing);
  }
}
```

### `lib/services/security.dart`

```dart
import 'package:local_auth/local_auth.dart';
import '../core/app_state.dart';

final _auth = LocalAuthentication();

/// true إذا نجح فتح القفل (بصمة / وجه / PIN الجهاز)
Future<bool> unlockDevice() async {
  try {
    // إذا الجهاز بدون قفل شاشة ما نقدر نحمي التطبيق، فنسمح بالدخول
    if (!await _auth.isDeviceSupported()) return true;
    return await _auth.authenticate(
      localizedReason: appState.t('Unlock A.Jami SOS', 'افتح تطبيق A.Jami SOS'),
      options: const AuthenticationOptions(stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}
```
