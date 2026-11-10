
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

// ================= Microsoft 365 / Outlook =================
class MsCal {
  // من Azure Portal ← App registrations (Android platform)
  static const clientId = 'YOUR_AZURE_APP_CLIENT_ID';
  static const redirect = 'msauth://com.ajami.sos/callback';
  static final _config = AuthorizationServiceConfiguration(
    authorizationEndpoint:
        'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
    tokenEndpoint:
        'https://login.microsoftonline.com/common/oauth2/v2.0/token',
  );
  static const _days = [
    'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];

  static Map<String, dynamic> _event(Task t) {
    final endDay = DateTime(t.date.year, t.date.month, t.date.day + 1);
    final range = <String, Object>{
      'type': 'noEnd',
      'startDate': dayKey(t.date),
    };
    final Map<String, Object>? recurrence = switch (t.recurrence) {
      'daily' => {
          'pattern': {'type': 'daily', 'interval': 1},
          'range': range,
        },
      'weekly' => {
          'pattern': {
            'type': 'weekly',
            'interval': 1,
            'daysOfWeek': [_days[t.date.weekday - 1]],
          },
          'range': range,
        },
      'monthly' => {
          'pattern': {
            'type': 'absoluteMonthly',
            'interval': 1,
            'dayOfMonth': t.date.day,
          },
          'range': range,
        },
      _ => null,
    };
    return {
      'subject': t.titleEn,
      'body': {'contentType': 'text', 'content': t.detailsEn},
      'isAllDay': true,
      'start': {'dateTime': '${dayKey(t.date)}T00:00:00', 'timeZone': 'UTC'},
      'end': {'dateTime': '${dayKey(endDay)}T00:00:00', 'timeZone': 'UTC'},
      if (recurrence != null) 'recurrence': recurrence,
    };
  }

  static Future<String> _token() async {
    final r = await FlutterAppAuth().authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirect,
        serviceConfiguration: _config,
        scopes: ['Calendars.ReadWrite', 'offline_access'],
      ),
    );
    final token = r?.accessToken;
    if (token == null) throw Exception('cancelled');
    return token;
  }

  static void _check(http.Response r) {
    if (r.statusCode >= 300) throw Exception('Graph ${r.statusCode}');
  }

  static Future<int> sync(List<Task> all) async {
    final headers = {
      'Authorization': 'Bearer ${await _token()}',
      'Content-Type': 'application/json',
    };
    final items = _pending(all, await _lastSync('ms'), (t) => t.msId);

    for (final t in items) {
      final body = jsonEncode(_event(t));
      if (t.msId == null) {
        final res = await http.post(
          Uri.parse('https://graph.microsoft.com/v1.0/me/events'),
          headers: headers,
          body: body,
        );
        _check(res);
        final id = jsonDecode(res.body)['id'] as String;
        await Db.instance.setSyncIds(t.id!, ms: id);
      } else {
        _check(await http.patch(
          Uri.parse('https://graph.microsoft.com/v1.0/me/events/${t.msId}'),
          headers: headers,
          body: body,
        ));
      }
    }
    await _markSynced('ms');
    return items.length;
  }
}

