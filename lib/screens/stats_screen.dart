import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/models.dart';

enum _Range { week, month, all }

class _Span {
  final DateTime from;
  final DateTime to;
  const _Span(this.from, this.to);
}

class _Report {
  int scheduled = 0;
  int done = 0;
  int missed = 0;
  // category -> [scheduled, done]
  final Map<String, List<int>> byCategory = {};

  double get rate => scheduled == 0 ? 0 : done / scheduled;
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Range _range = _Range.week;
  bool _loading = true;
  List<Task> _tasks = [];
  Set<String> _doneKeys = {};

  String s(String en, String ar) => appState.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await Db.instance.tasks();
    final done = await Db.instance.completionKeys();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _doneKeys = done;
      _loading = false;
    });
  }

  // Adding days through the constructor avoids DST issues.
  DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  // Periods end today, so future tasks are not counted as missed.
  _Span _span() {
    final today = dateOnly(DateTime.now());
    switch (_range) {
      case _Range.week:
        return _Span(_addDays(today, -6), today);
      case _Range.month:
        return _Span(DateTime(today.year, today.month, 1), today);
      case _Range.all:
        var first = today;
        for (final t in _tasks) {
          final d = dateOnly(t.date);
          if (d.isBefore(first)) first = d;
        }
        return _Span(first, today);
    }
  }

  _Report _compute(_Span span) {
    final r = _Report();
    for (var d = span.from; !d.isAfter(span.to); d = _addDays(d, 1)) {
      for (final t in _tasks) {
        final id = t.id;
        if (id == null || !t.occursOn(d)) continue;
        final isDone = _doneKeys.contains(doneKey(id, d));
        final cat = r.byCategory.putIfAbsent(t.category, () => [0, 0]);
        r.scheduled++;
        cat[0]++;
        if (isDone) {
          r.done++;
          cat[1]++;
        } else if (d.isBefore(span.to)) {
          // Not done and the day has passed.
          r.missed++;
        }
      }
    }
    return r;
  }

  Widget _tile(String label, int value, Color color) => Expanded(
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            Text(label, style: const TextStyle(color: kDimGreen, fontSize: 12)),
          ],
        ),
      );

  Widget _summary(_Report r, _Span span) {
    final pct = (r.rate * 100).round();
    return Card(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: kGreen,
              ),
            ),
            Text(s('Completion rate', 'نسبة الإنجاز'),
                style: const TextStyle(color: kDimGreen)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: r.rate,
              color: kGreen,
              backgroundColor: kDimGreen.withAlpha(51),
              minHeight: 6,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _tile(s('Done', 'منجز'), r.done, kGreen),
                _tile(s('Scheduled', 'مجدول'), r.scheduled, kDimGreen),
                _tile(s('Missed', 'فائت'), r.missed, kRed),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dayKey(span.from)} – ${dayKey(span.to)}',
              style: const TextStyle(color: kDimGreen, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categories(_Report r) {
    if (r.byCategory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          s('No tasks in this period', 'ما في مهام بهالفترة'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: kDimGreen),
        ),
      );
    }
    final entries = r.byCategory.entries.toList()
      ..sort((a, b) => b.value[0].compareTo(a.value[0]));
    return Column(
      children: [
        for (final e in entries)
          Card(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 10, color: catColor(e.key)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(catLabel(e.key))),
                      Text('${e.value[1]} / ${e.value[0]}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: e.value[0] == 0 ? 0 : e.value[1] / e.value[0],
                    color: catColor(e.key),
                    backgroundColor: kDimGreen.withAlpha(51),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final span = _span();
    final r = _compute(span);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(s('Reports', 'التقارير'))),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kGreen))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<_Range>(
                    segments: [
                      ButtonSegment(
                        value: _Range.week,
                        label: Text(s('Week', 'أسبوع')),
                      ),
                      ButtonSegment(
                        value: _Range.month,
                        label: Text(s('Month', 'شهر')),
                      ),
                      ButtonSegment(
                        value: _Range.all,
                        label: Text(s('All time', 'كل الوقت')),
                      ),
                    ],
                    selected: {_range},
                    onSelectionChanged: (v) => setState(() => _range = v.first),
                  ),
                  const SizedBox(height: 16),
                  _summary(r, span),
                  const SizedBox(height: 16),
                  _categories(r),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}
