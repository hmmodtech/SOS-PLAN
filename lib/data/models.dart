
```dart
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
  return (jsonDecode(raw) as List)
      .map((e) => CheckItem.fromJson(e as Map<String, dynamic>))
      .toList();
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
        id: m['id'] as int,
        titleEn: m['title_en'] as String,
        titleAr: (m['title_ar'] as String?) ?? '',
        detailsEn: (m['details_en'] as String?) ?? '',
        detailsAr: (m['details_ar'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
        remindAt: m['remind_at'] == null
            ? null
            : DateTime.parse(m['remind_at'] as String),
        category: m['category'] as String,
        priority: m['priority'] as int,
        isPrivate: m['is_private'] == 1,
        recurrence: m['recurrence'] as String,
        checklist: _parseChecklist(m['checklist'] as String?),
        isMission: m['is_mission'] == 1,
        googleId: m['google_id'] as String?,
        msId: m['ms_id'] as String?,
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

class Note {
  final int id;
  final DateTime day;
  final String text;
  const Note({required this.id, required this.day, required this.text});

  factory Note.fromMap(Map<String, Object?> m) => Note(
        id: m['id'] as int,
        day: DateTime.parse(m['day'] as String),
        text: m['text'] as String,
      );
}
```
