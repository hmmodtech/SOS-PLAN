import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../services/notifications.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;
  final DateTime initialDate;
  const TaskFormScreen({super.key, this.task, required this.initialDate});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _titleEn;
  late final TextEditingController _titleAr;
  late final TextEditingController _detailsEn;
  late final TextEditingController _detailsAr;
  late final TextEditingController _checklist;

  late DateTime _date;
  DateTime? _remindAt;
  late String _category;
  late int _priority; // 0 low, 1 normal, 2 high
  late bool _isPrivate;
  late String _recurrence;

  final SpeechToText _stt = SpeechToText();
  bool _sttReady = false;
  TextEditingController? _listeningTo;

  String s(String en, String ar) => appState.t(en, ar);

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleEn = TextEditingController(text: t?.titleEn ?? '');
    _titleAr = TextEditingController(text: t?.titleAr ?? '');
    _detailsEn = TextEditingController(text: t?.detailsEn ?? '');
    _detailsAr = TextEditingController(text: t?.detailsAr ?? '');
    _checklist = TextEditingController(
      text: (t?.checklist ?? [])
          .map((c) => '${c.done ? '[x]' : '[ ]'} ${c.text}')
          .join('\n'),
    );
    _date = dateOnly(t?.date ?? widget.initialDate);
    _remindAt = t?.remindAt;
    _category = t?.category ?? 'general';
    _priority = t?.priority ?? 1;
    _isPrivate = t?.isPrivate ?? false;
    _recurrence = t?.recurrence ?? 'none';
    _stt.initialize().then((ok) {
      if (mounted) setState(() => _sttReady = ok);
    });
  }

  @override
  void dispose() {
    _titleEn.dispose();
    _titleAr.dispose();
    _detailsEn.dispose();
    _detailsAr.dispose();
    _checklist.dispose();
    _stt.stop();
    super.dispose();
  }

  Future<void> _toggleVoice(TextEditingController c) async {
    if (!_sttReady) return;
    if (_stt.isListening) {
      await _stt.stop();
      setState(() => _listeningTo = null);
      return;
    }
    setState(() => _listeningTo = c);
    await _stt.listen(
      localeId: appState.isArabic ? 'ar_SA' : 'en_US',
      onResult: (r) {
        c.text = r.recognizedWords;
        c.selection = TextSelection.collapsed(offset: c.text.length);
      },
    );
  }

  Widget _mic(TextEditingController c) => IconButton(
        icon: Icon(
          _listeningTo == c ? Icons.mic : Icons.mic_none,
          color: _listeningTo == c ? kRed : kGreen,
        ),
        tooltip: s('Voice input', 'إدخال صوتي'),
        onPressed: _sttReady ? () => _toggleVoice(c) : null,
      );

  Widget _field(TextEditingController c, String label, {int lines = 1, bool voice = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: voice ? _mic(c) : null,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = dateOnly(d));
  }

  Future<void> _pickBellTime() async {
    final base = _remindAt ?? DateTime(_date.year, _date.month, _date.day, 9);
    final tm = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (tm != null) {
      setState(() {
        _remindAt = DateTime(_date.year, _date.month, _date.day, tm.hour, tm.minute);
      });
    }
  }

  List<CheckItem> _parseChecklist(List<CheckItem> old) {
    final lines = _checklist.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    final result = <CheckItem>[];
    var i = 0;
    for (final line in lines) {
      final done = line.startsWith('[x]');
      final text = line.replaceFirst(RegExp(r'^\[(x| )\]\s*'), '');
      // keep previous done state if the item was already there at this position
      final keepDone = i < old.length && old[i].text == text ? old[i].done : done;
      result.add(CheckItem(text, done: keepDone));
      i++;
    }
    return result;
  }

  Future<void> _save() async {
    final hasTitle = _titleEn.text.trim().isNotEmpty || _titleAr.text.trim().isNotEmpty;
    if (!hasTitle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s('Please enter a title', 'اكتب عنوان المهمة'))),
      );
      return;
    }
    final old = widget.task;
    final task = Task(
      id: old?.id,
      titleEn: _titleEn.text.trim(),
      titleAr: _titleAr.text.trim(),
      detailsEn: _detailsEn.text.trim(),
      detailsAr: _detailsAr.text.trim(),
      date: _date,
      remindAt: _remindAt,
      category: _category,
      priority: _priority,
      isPrivate: _isPrivate,
      recurrence: _recurrence,
      checklist: _parseChecklist(old?.checklist ?? []),
      isMission: old?.isMission ?? false,
      googleId: old?.googleId,
      msId: old?.msId,
      updatedAt: DateTime.now(),
    );
    final id = await Db.instance.saveTask(task);
    await Bell.schedule(task, id, enabled: appState.notificationsOn);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final old = widget.task;
    if (old?.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('Delete task?', 'تحذف المهمة؟')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s('Cancel', 'إلغاء'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s('Delete', 'حذف'))),
        ],
      ),
    );
    if (ok != true) return;
    await Bell.cancel(old!.id!);
    await Db.instance.deleteTask(old.id!);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.task == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? s('New task', 'مهمة جديدة') : s('Edit task', 'تعديل المهمة')),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: s('Delete', 'حذف'),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_titleEn, s('Title (English)', 'العنوان (إنجليزي)')),
            _field(_titleAr, s('Title (Arabic)', 'العنوان (عربي)')),
            _field(_detailsEn, s('Details (English)', 'التفاصيل (إنجليزي)'), lines: 3),
            _field(_detailsAr, s('Details (Arabic)', 'التفاصيل (عربي)'), lines: 3),
            _field(_checklist, s('Checklist (one item per line)', 'قائمة فرعية (بند في كل سطر)'),
                lines: 4, voice: false),
            Card(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.event, color: kGreen),
                title: Text(s('Date', 'التاريخ')),
                subtitle: Text(dayKey(_date)),
                onTap: _pickDate,
              ),
            ),
            Card(
              color: Colors.transparent,
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_active, color: kGreen),
                title: Text(s('Bell reminder', 'تذكير بالجرس')),
                subtitle: Text(_remindAt == null
                    ? s('Off', 'مغلق')
                    : '${_remindAt!.hour.toString().padLeft(2, '0')}:${_remindAt!.minute.toString().padLeft(2, '0')}'),
                value: _remindAt != null,
                onChanged: (on) {
                  if (on) {
                    _pickBellTime();
                  } else {
                    setState(() => _remindAt = null);
                  }
                },
              ),
            ),
            if (_remindAt != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _pickBellTime,
                  child: Text(s('Change reminder time', 'تغيير وقت التذكير')),
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(labelText: s('Category', 'الفئة')),
              items: kCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(catLabel(c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'general'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _priority,
              decoration: InputDecoration(labelText: s('Priority', 'الأولوية')),
              items: [
                DropdownMenuItem(value: 0, child: Text(s('Low', 'منخفضة'))),
                DropdownMenuItem(value: 1, child: Text(s('Normal', 'عادية'))),
                DropdownMenuItem(value: 2, child: Text(s('High', 'عالية'))),
              ],
              onChanged: (v) => setState(() => _priority = v ?? 1),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _recurrence,
              decoration: InputDecoration(labelText: s('Repeat', 'التكرار')),
              items: kRepeats
                  .map((r) => DropdownMenuItem(value: r, child: Text(repeatLabel(r))))
                  .toList(),
              onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
            ),
            const SizedBox(height: 8),
            Card(
              color: Colors.transparent,
              child: SwitchListTile(
                secondary: const Icon(Icons.lock_outline, color: kGreen),
                title: Text(s('Private (never synced or exported)', 'خاصة (ما بتنرسل ولا بتتصدّر)')),
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(s('Save', 'حفظ')),
            ),
          ],
        ),
      ),
    );
  }
}
