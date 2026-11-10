
import 'dart:convert';

const kCategories = ['general', 'security', 'logistics', 'child', 'admin'];
const kRepeats = ['none', 'daily', 'weekly', 'monthly'];

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// قراءة نص محفوظ في قاعدة البيانات بلا انفجار عند القيمة الفارغة.
/// (كل الحقول النصية في الجداول قابلة لأن تكون NULL.)
String _text(Object? v) => (v as String?) ?? '';

/// أرقام SQLite قد تُعاد كـ int أو num حسب المنصّة.
int _int(Object? v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : fallback);

DateTime _date(Object? v) => DateTime.parse(_text(v));

/// مفتاح إنجاز مهمة في يوم محدد (كل يوم في المهمة المتكررة له حالة مستقلة)
String doneKey(int taskId, DateTime day) => '$taskId|${dayKey(day)}';

class CheckItem {
  final String text;
  final bool done;
  const CheckItem(this.text, {this.done = false});

  Map<String, dynamic> toJson() => {'t': text, 'd': done};

  factory CheckItem.fromJson(Map<String, dynamic> m) =>
      CheckItem(m['t'] as String, done: m['d'] as bool);
}

List<CheckItem> _parseChecklist(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((e) => CheckItem(
              (e['t'] as String?) ?? '',
              done: e['d'] == true,
            ))
        .toList();
  } catch (_) {
    // Corrupt JSON must not crash the list screen.
    return const [];
  }
}

class Task {
  final int? id;
  final String titleEn;
  final String titleAr;
  final String detailsEn;
  final String detailsAr;
  final DateTime date;      // اليوم فقط
  final DateTime? remindAt; // الساعة والدقيقة تُستخدم للجرس
  final String category;    // general | security | logistics | child | admin
  final int priority;       // 0 منخفضة، 1 عادية، 2 عالية
  final bool isPrivate;     // لا تُرسل للتقاويم السحابية
  final String recurrence;  // none | daily | weekly | monthly
  final List<CheckItem> checklist;
  final bool isMission;     // جزء من خطة D1–D20
  final String? googleId;
  final String? msId;
  final DateTime updatedAt;

  const Task({
    this.id,
    required this.titleEn,
    this.titleAr = '',
    this.detailsEn = '',
    this.detailsAr = '',
    required this.date,
    this.remindAt,
    this.category = 'general',
    this.priority = 1,
    this.isPrivate = false,
    this.recurrence = 'none',
    this.checklist = const [],
    this.isMission = false,
    this.googleId,
    this.msId,
    required this.updatedAt,
  });

  String title(bool ar) => ar && titleAr.isNotEmpty ? titleAr : titleEn;
  String details(bool ar) => ar && detailsAr.isNotEmpty ? detailsAr : detailsEn;

  /// وقت الجرس في يوم معين
  DateTime? bellOn(DateTime day) => remindAt == null
      ? null
      : DateTime(day.year, day.month, day.day, remindAt!.hour, remindAt!.minute);

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final s = dateOnly(date);
    if (d.isBefore(s)) return false;
    return switch (recurrence) {
      'daily' => true,
      'weekly' => d.weekday == s.weekday,
      'monthly' => d.day == s.day,
      _ => sameDay(d, s),
    };
  }

  Map<String, Object?> toMap() => {
        'title_en': titleEn,
        'title_ar': titleAr,
        'details_en': detailsEn,
        'details_ar': detailsAr,
        'date': dayKey(date),
        'remind_at': remindAt?.toIso8601String(),
        'category': category,
        'priority': priority,
        'is_private': isPrivate ? 1 : 0,
        'recurrence': recurrence,
        'checklist': jsonEncode(checklist.map((c) => c.toJson()).toList()),
        'is_mission': isMission ? 1 : 0,
        'google_id': googleId,
        'ms_id': msId,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: _int(m['id']),
        titleEn: _text(m['title_en']),
        titleAr: _text(m['title_ar']),
        detailsEn: _text(m['details_en']),
        detailsAr: _text(m['details_ar']),
        date: _date(m['date']),
        remindAt: m['remind_at'] == null ? null : _date(m['remind_at']),
        category: m['category'] == null ? 'general' : _text(m['category']),
        priority: _int(m['priority'], 1),
        isPrivate: _int(m['is_private']) == 1,
        recurrence: m['recurrence'] == null ? 'none' : _text(m['recurrence']),
        checklist: _parseChecklist(m['checklist'] as String?),
        isMission: _int(m['is_mission']) == 1,
        googleId: m['google_id'] as String?,
        msId: m['ms_id'] as String?,
        updatedAt: m['updated_at'] == null
            ? DateTime.now()
            : _date(m['updated_at']),
      );
}

class Note {
  final int id;
  final DateTime day;
  final String text;
  const Note({required this.id, required this.day, required this.text});

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: _int(m['id']),
        day: _date(m['day']),
        text: _text(m['text']),
      );
}

