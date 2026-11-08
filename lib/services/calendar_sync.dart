```dart
import 'dart:convert';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart';
import '../data/models.dart';

/// مزامنة من التطبيق إلى التقويم (Push).
/// - المهام المعدّلة بعد آخر مزامنة تُرسل (Outbox عبر updated_at)
/// - Last-write-wins: التطبيق هو المصدر الأساسي
/// - المهام الخاصة (isPrivate) لا تُرسل أبداً

Future<DateTime> _lastSync(String provider) async {
  final prefs = await SharedPreferences.getInstance();
  return DateTime.fromMillisecondsSinceEpoch(prefs.getInt('sync_$provider') ?? 0);
}

Future<void> _markSynced(String provider) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt('sync_$provider', DateTime.now().millisecondsSinceEpoch);
}

List<Task> _pending(
  List<Task> all,
  DateTime since,
  String? Function(Task) remoteId,
) =>
    all
        .where((t) =>
            !t.isPrivate && (remoteId(t) == null || t.updatedAt.isAfter(since)))
        .toList();

// ================= Google Calendar =================
class GoogleCal {
  // Client ID يُنشأ من Google Cloud (نوع Android) ويُربط بالـ package name و SHA-1
  static final _gsi = GoogleSignIn(
    scopes: [gcal.CalendarApi.calendarEventsScope],
  );

  static Future<int> sync(List<Task> all) async {
    if (await _gsi.signIn() == null) throw Exception('cancelled');
    final client = await _gsi.authenticatedClient();
    if (client == null) throw Exception('no auth client');
    final api = gcal.CalendarApi(client);

    final items = _pending(all, await _lastSync('google'), (t) => t.googleId);
    for (final t in items) {
      final start = DateTime.utc(t.date.year, t.date.month, t.date.day);
      final event = gcal.Event(
        summary: t.titleEn,
        description: t.detailsEn,
        start: gcal.EventDateTime(date: start),
        end: gcal.EventDateTime(
            date: DateTime.utc(start.year, start.month, start.day + 1)),
        recurrence: t.recurrence == 'none'
            ? null
            : ['RRULE:FREQ=${t.recurrence.toUpperCase()}'],
      );
      if (t.googleId == null) {
        final created = await api.events.insert(event, 'primary');
        await Db.instance.setSyncIds(t.id!, google: created.id);
      } else {
        await api.events.update(event, 'primary', t.googleId!);
      }
    }
    await _markSynced('google');
    return items.length;
  }
}
