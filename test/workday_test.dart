import 'package:flutter_test/flutter_test.dart';
import '../lib/data/models.dart';
import '../lib/data/seed.dart';

Task _task({required DateTime date, String recurrence = 'none'}) => Task(
      titleEn: 'Test',
      titleAr: '',
      detailsEn: '',
      detailsAr: '',
      date: date,
      remindAt: null,
      category: 'general',
      priority: 1,
      isPrivate: false,
      recurrence: recurrence,
      checklist: const [],
      isMission: false,
      googleId: null,
      msId: null,
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  group('nextWorkday', () {
    test('Friday moves to Sunday', () {
      expect(nextWorkday(DateTime(2026, 11, 20)), DateTime(2026, 11, 22));
    });

    test('Saturday moves to Sunday', () {
      expect(nextWorkday(DateTime(2026, 11, 21)), DateTime(2026, 11, 22));
    });

    test('Thursday stays Thursday', () {
      expect(nextWorkday(DateTime(2026, 11, 19)), DateTime(2026, 11, 19));
    });

    test('crosses year end', () {
      // 1 Jan 2027 is a Friday
      expect(nextWorkday(DateTime(2027, 1, 1)), DateTime(2027, 1, 3));
    });
  });

  group('mission D1–D20', () {
    final mission = missionFrom(DateTime(2026, 11, 16));

    test('has 20 tasks', () {
      expect(mission.length, 20);
    });

    test('no task falls on Friday or Saturday', () {
      for (final t in mission) {
        expect(t.date.weekday != DateTime.friday, isTrue, reason: '${t.date}');
        expect(t.date.weekday != DateTime.saturday, isTrue, reason: '${t.date}');
      }
    });

    test('starts 16 Nov and ends 13 Dec 2026', () {
      expect(sameDay(mission.first.date, DateTime(2026, 11, 16)), isTrue);
      expect(sameDay(mission.last.date, DateTime(2026, 12, 13)), isTrue);
    });
  });

  group('occursOn', () {
    test('one-off task occurs only on its own day, in any year', () {
      final t = _task(date: DateTime(2031, 3, 9));
      expect(t.occursOn(DateTime(2031, 3, 9)), isTrue);
      expect(t.occursOn(DateTime(2031, 3, 10)), isFalse);
      expect(t.occursOn(DateTime(2032, 3, 9)), isFalse);
    });

    test('daily repeats every day', () {
      final t = _task(date: DateTime(2026, 11, 16), recurrence: 'daily');
      expect(t.occursOn(DateTime(2026, 11, 20)), isTrue);
    });

    test('weekly repeats on the same weekday', () {
      final t = _task(date: DateTime(2026, 11, 22), recurrence: 'weekly'); // Sunday
      expect(t.occursOn(DateTime(2026, 11, 29)), isTrue);
      expect(t.occursOn(DateTime(2026, 11, 23)), isFalse);
    });

    test('monthly repeats on the same day of month', () {
      final t = _task(date: DateTime(2026, 11, 16), recurrence: 'monthly');
      expect(t.occursOn(DateTime(2027, 4, 16)), isTrue);
      expect(t.occursOn(DateTime(2027, 4, 17)), isFalse);
    });
  });

  group('done keys', () {
    test('format is taskId|yyyy-MM-dd', () {
      expect(doneKey(7, DateTime(2026, 11, 16)), '7|2026-11-16');
    });
  });
}
