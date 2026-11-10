

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../services/notifications.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'task_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _memo = TextEditingController();
  DateTime _focused = DateTime.now();
  DateTime _selected = dateOnly(DateTime.now());
  List<Task> _tasks = [];
  Set<String> _done = {};
  List<Note> _notes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = Db.instance;
    final tasks = await db.tasks();
    final done = await db.completionKeys();
    final notes = await db.notesOn(_selected);
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _done = done;
      _notes = notes;
    });
  }

  List<Task> _tasksOn(DateTime d) =>
      _tasks.where((t) => t.occursOn(d)).toList()
        ..sort((a, b) => b.priority.compareTo(a.priority));

  bool _isDone(Task t, DateTime d) => _done.contains(doneKey(t.id!, d));

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _focused = now;
      _selected = dateOnly(now);
    });
    _load();
  }

  Future<void> _toggle(Task t) async {
    final nowDone = !_isDone(t, _selected);
    HapticFeedback.mediumImpact();
    await Db.instance.setDone(t.id!, _selected, nowDone);
    await Bell.schedule(t, t.id!,
        enabled: appState.notificationsOn, done: nowDone);
    await _load();
  }

  Future<void> _toggleCheck(Task t, int i) async {
    HapticFeedback.selectionClick();
    await Db.instance.setChecklistDone(t.id!, i, !t.checklist[i].done);
    await _load();
  }

  Future<void> _delete(Task t) async {
    await Db.instance.deleteTask(t.id!);
    await Bell.cancel(t.id!);
    await _load();
  }

  Future<bool> _confirm(String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF031A08),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(appState.t('Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(appState.t('Delete', 'حذف'),
                style: const TextStyle(color: kRed)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _openForm([Task? t]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(task: t, initialDate: _selected),
      ),
    );
    _load();
  }

  Future<void> _search() async {
    final day = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (day != null) {
      setState(() {
        _selected = dateOnly(day);
        _focused = day;
      });
    }
    _load();
  }

  Future<void> _pickYearMonth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _focused,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) {
      setState(() {
        _focused = d;
        _selected = dateOnly(d);
      });
      _load();
    }
  }

  Future<void> _addMemo() async {
    final text = _memo.text.trim();
    if (text.isEmpty) return;
    await Db.instance.addNote(_selected, text);
    _memo.clear();
    _load();
  }

  // ---------- UI helpers ----------
  Widget _section(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(s,
            style: const TextStyle(
                color: kGreen,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 12)),
      );

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withAlpha(35),
          border: Border.all(color: c.withAlpha(140)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
      );

  Widget _taskCard(Task t) {
    final ar = appState.isArabic;
    final done = _isDone(t, _selected);
    final color = catColor(t.category);

    final card = AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: done ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 8),
        decoration: glass(border: color.withAlpha(120)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Checkbox(
                value: done,
                activeColor: kGreen,
                checkColor: Colors.black,
                onChanged: (_) => _toggle(t),
              ),
              Expanded(
                child: Text(
                  t.title(ar),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (t.isPrivate)
                const Icon(Icons.lock_outline, size: 16, color: kAmber),
              if (t.remindAt != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Row(children: [
                    const Icon(Icons.notifications_active, size: 16, color: kGreen),
                    const SizedBox(width: 3),
                    Text(DateFormat.Hm().format(t.remindAt!),
                        style: const TextStyle(color: kGreen, fontSize: 12)),
                  ]),
                ),
            ]),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                _chip(catLabel(t.category), color),
                if (t.recurrence != 'none')
                  _chip('↻ ${repeatLabel(t.recurrence)}', kDimGreen),
                if (t.priority == 2)
                  _chip(appState.t('HIGH', 'عالية'), kRed),
              ]),
            ),
            if (t.details(ar).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
                child: Text(t.details(ar),
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1.35)),
              ),
            for (var i = 0; i < t.checklist.length; i++)
              InkWell(
                onTap: () => _toggleCheck(t, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
                  child: Row(children: [
                    Icon(
                      t.checklist[i].done
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: kGreen,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.checklist[i].text,
                        style: TextStyle(
                          fontSize: 12,
                          decoration: t.checklist[i].done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('t${t.id}-${dayKey(_selected)}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: kRed.withAlpha(90),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) => _confirm(appState.t(
          'Delete this task permanently?', 'حذف هذه المهمة نهائياً؟')),
      onDismissed: (_) => _delete(t),
      child: InkWell(
        onTap: () => _openForm(t),
        borderRadius: BorderRadius.circular(10),
        child: card,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final s = appState;
        final ar = s.isArabic;
        final dayTasks = _tasksOn(_selected);

        return Scaffold(
          appBar: AppBar(
            title: const Text('A.JAMI SOS'),
            actions: [
              IconButton(
                tooltip: 'Panic',
                icon: const Icon(Icons.shield_outlined, color: kRed),
                onPressed: () => s.setPanic(true),
              ),
              IconButton(icon: const Icon(Icons.search), onPressed: _search),
              TextButton(
                onPressed: () => s.setArabic(!ar),
                child: Text(ar ? 'EN' : 'AR',
                    style: const TextStyle(
                        color: kGreen, fontWeight: FontWeight.w900)),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kGreen,
            foregroundColor: Colors.black,
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: Text(s.t('NEW TASK', 'مهمة جديدة'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 100),
            children: [
              Container(
                decoration: glass(),
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
                child: TableCalendar<Task>(
                  locale: ar ? 'ar' : 'en_US',
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2100),
                  focusedDay: _focused,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  weekendDays: const [DateTime.friday, DateTime.saturday],
                  selectedDayPredicate: (d) => sameDay(d, _selected),
                  eventLoader: _tasksOn,
                  onDaySelected: (sel, foc) {
                    setState(() {
                      _selected = dateOnly(sel);
                      _focused = foc;
                    });
                    _load();
                  },
                  onPageChanged: (f) => _focused = f,
                  onHeaderTapped: (_) => _pickYearMonth(),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle:
                        TextStyle(color: kGreen, fontWeight: FontWeight.w800),
                    leftChevronIcon: Icon(Icons.chevron_left, color: kGreen),
                    rightChevronIcon: Icon(Icons.chevron_right, color: kGreen),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: Colors.white54),
                    weekendStyle: TextStyle(color: kDimGreen),
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle: const TextStyle(color: Colors.white70),
                    weekendTextStyle: TextStyle(color: kDimGreen.withAlpha(170)),
                    selectedDecoration: BoxDecoration(
                      color: kGreen.withAlpha(60),
                      shape: BoxShape.circle,
                      border: Border.all(color: kGreen),
                    ),
                    selectedTextStyle: const TextStyle(
                        color: kGreen, fontWeight: FontWeight.bold),
                    todayDecoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kDimGreen),
                    ),
                    todayTextStyle: const TextStyle(color: kGreen),
                    markerDecoration: const BoxDecoration(
                        color: kGreen, shape: BoxShape.circle),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: Text(
                    DateFormat.yMMMMEEEEd(ar ? 'ar' : 'en_US')
                        .format(_selected)
                        .toUpperCase(),
                    style: const TextStyle(
                        color: kGreen,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1),
                  ),
                ),
                TextButton(
                  onPressed: _goToday,
                  child: Text(s.t('TODAY', 'اليوم')),
                ),
              ]),

              _section(s.t('TASKS', 'المهام')),
              if (dayTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(s.t('No tasks for this day', 'لا توجد مهام لهذا اليوم'),
                      style: const TextStyle(color: Colors.white38)),
                ),
              ...dayTasks.map(_taskCard),

              _section(s.t('MEMOS', 'المذكرات')),
              for (final n in _notes)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: glass(border: kDimGreen.withAlpha(90)),
                  child: ListTile(
                    dense: true,
                    title: Text(n.text),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        await Db.instance.deleteNote(n.id);
                        _load();
                      },
                    ),
                  ),
                ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _memo,
                    onSubmitted: (_) => _addMemo(),
                    decoration: InputDecoration(
                      hintText: s.t('Write a memo...', 'اكتب مذكرة...'),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addMemo,
                  icon: const Icon(Icons.send, color: kGreen),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

