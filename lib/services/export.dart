
import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/database.dart';
import '../data/models.dart';

String _ymd(DateTime d) => dayKey(d).replaceAll('-', '');

String _icsStamp(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_ymd(u)}T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
    .replaceAll('\n', '\\n');

/// ملف ICS يُفتح في Google Calendar و Outlook مباشرة. المهام الخاصة لا تُصدَّر.
String toIcs(List<Task> tasks) {
  final b = StringBuffer(
      'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//A.Jami SOS//EN\r\nCALSCALE:GREGORIAN\r\n');
  for (final t in tasks.where((t) => !t.isPrivate)) {
    final next = DateTime(t.date.year, t.date.month, t.date.day + 1);
    final rule = switch (t.recurrence) {
      'daily' => 'FREQ=DAILY',
      'weekly' => 'FREQ=WEEKLY',
      'monthly' => 'FREQ=MONTHLY',
      _ => '',
    };
    b.write('BEGIN:VEVENT\r\n'
        'UID:sos-${t.id}@ajami\r\n'
        'DTSTAMP:${_icsStamp(t.updatedAt)}\r\n'
        'SUMMARY:${_esc(t.titleEn)}\r\n'
        'DESCRIPTION:${_esc(t.detailsEn)}\r\n'
        'DTSTART;VALUE=DATE:${_ymd(t.date)}\r\n'
        'DTEND;VALUE=DATE:${_ymd(next)}\r\n'
        '${rule.isEmpty ? '' : 'RRULE:$rule\r\n'}'
        'END:VEVENT\r\n');
  }
  b.write('END:VCALENDAR\r\n');
  return b.toString();
}

String toCsv(List<Task> tasks) {
  String q(String s) => '"${s.replaceAll('"', '""')}"';
  final b = StringBuffer(
      'date,title_en,title_ar,details_en,category,priority,recurrence\n');
  for (final t in tasks.where((t) => !t.isPrivate)) {
    b.writeln([
      dayKey(t.date),
      q(t.titleEn),
      q(t.titleAr),
      q(t.detailsEn),
      t.category,
      t.priority,
      t.recurrence,
    ].join(','));
  }
  return b.toString();
}

Future<void> shareFile(String name, String content, String mime) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$name');
  await file.writeAsString(content);
  await Share.shareXFiles([XFile(file.path, mimeType: mime)]);
}

Future<void> exportBackup() async {
  final data = jsonEncode(await Db.instance.exportAll());
  await shareFile('sos_backup.json', data, 'application/json');
}

/// يرجع true إذا تمت الاستعادة
Future<bool> importBackup() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  final bytes = res?.files.single.bytes;
  if (bytes == null) return false;
  await Db.instance.importAll(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
  return true;
}
