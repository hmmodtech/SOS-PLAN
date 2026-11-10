import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/models.dart';

class Bell {
  Bell._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const String _channelId = 'sos_tasks';
  static const int _digestId = 999001;
  static bool _ready = false;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Task reminders',
      channelDescription: 'Bell reminders for tasks',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    try {
       final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier)); 
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Task reminders',
      description: 'Bell reminders for tasks',
      importance: Importance.high,
    ));
    await android?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> schedule(Task t, int id,
      {required bool enabled, bool done = false}) async {
    await cancel(id);
    final remind = t.remindAt;
    if (!enabled || done || remind == null) return;

    final when = tz.TZDateTime.from(remind, tz.local);
    final recurring = t.recurrence != 'none';
    if (!recurring && when.isBefore(tz.TZDateTime.now(tz.local))) return;

    final DateTimeComponents? match = switch (t.recurrence) {
      'daily' => DateTimeComponents.time,
      'weekly' => DateTimeComponents.dayOfWeekAndTime,
      'monthly' => DateTimeComponents.dayOfMonthAndTime,
      _ => null,
    };

    final details = t.details(appState.isArabic);
    await _plugin.zonedSchedule(
      id,
      t.title(appState.isArabic),
      details.isEmpty ? catLabel(t.category) : details,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: match,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);

  static Future<void> digest({required bool enabled}) async {
    await cancel(_digestId);
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, 7, 30);
    if (at.isBefore(now)) at = at.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _digestId,
      'A.Jami SOS',
      appState.t("Open the app to see today's tasks",
          'افتح التطبيق لتشوف مهام اليوم'),
      at,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> test() async {
    await init();
    await _plugin.show(
      0,
      'A.Jami SOS',
      appState.t('Test notification works', 'الإشعار التجريبي شغّال'),
      _details,
    );
  }

  static Future<void> resyncAll() async {
    await init();
    await _plugin.cancelAll();
    final tasks = await Db.instance.tasks();
    final doneKeys = await Db.instance.completionKeys();
    final on = appState.notificationsOn;
    for (final t in tasks) {
      final id = t.id;
      if (id == null) continue;
      final done = t.recurrence == 'none' &&
          doneKeys.contains(doneKey(id, dateOnly(t.date)));
      await schedule(t, id, enabled: on, done: done);
    }
    await digest(enabled: on && appState.morningBriefing);
  }
}
