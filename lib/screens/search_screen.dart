import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/models.dart';

class _Hit {
  final DateTime day;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _Hit({
    required this.day,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Task> _tasks = [];
  List<Note> _notes = [];
  bool _loading = true;
  String _query = '';

  String s(String en, String ar) => appState.t(en, ar);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tasks = await Db.instance.tasks();
    final notes = await Db.instance.allNotes();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _notes = notes;
      _loading = false;
    });
  }

  // Note.day is stored as a date key; this accepts either a DateTime or a 'yyyy-MM-dd' string.
  DateTime _noteDay(Object v) => dateOnly(DateTime.parse(v.toString()));

  List<_Hit> _search(String q) {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return const [];

    bool hit(String? text) => text != null && text.toLowerCase().contains(needle);

    final out = <_Hit>[];

    for (final t in _tasks) {
      final inChecklist = t.checklist.any((c) => hit(c.text));
      final matched = hit(t.titleEn) ||
          hit(t.titleAr) ||
          hit(t.detailsEn) ||
          hit(t.detailsAr) ||
          inChecklist;
      if (!matched) continue;
      out.add(_Hit(
        day: dateOnly(t.date),
        title: t.title(appState.isArabic),
        subtitle: '${dayKey(t.date)} · ${catLabel(t.category)}',
        icon: Icons.checklist,
        color: catColor(t.category),
      ));
    }

    for (final n in _notes) {
      if (!hit(n.text)) continue;
      final firstLine = n.text.trim().split('\n').first;
      final day = _noteDay(n.day);
      out.add(_Hit(
        day: day,
        title: firstLine.length > 60 ? '${firstLine.substring(0, 60)}…' : firstLine,
        subtitle: '${dayKey(day)} · ${s('Memo', 'ملاحظة')}',
        icon: Icons.sticky_note_2_outlined,
        color: kGreen,
      ));
    }

    out.sort((a, b) => a.day.compareTo(b.day));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final hits = _search(_query);
    final hasQuery = _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s('Search tasks and memos…', 'ابحث في المهام والملاحظات…'),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: s('Clear', 'مسح'),
              onPressed: () {
                _ctrl.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: kGreen))
            : !hasQuery
                ? Center(
                    child: Text(
                      s('Type a word to search', 'اكتب كلمة للبحث'),
                      style: const TextStyle(color: kDimGreen),
                    ),
                  )
                : hits.isEmpty
                    ? Center(
                        child: Text(
                          s('No results', 'ما في نتائج'),
                          style: const TextStyle(color: kDimGreen),
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                '${hits.length} ${s('results', 'نتيجة')}',
                                style: const TextStyle(color: kDimGreen),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: hits.length,
                              itemBuilder: (_, i) {
                                final h = hits[i];
                                return Card(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    leading: Icon(h.icon, color: h.color),
                                    title: Text(h.title),
                                    subtitle: Text(h.subtitle),
                                    trailing: const Icon(Icons.chevron_right, color: kDimGreen),
                                    // Returns the chosen day to HomeScreen, which selects it.
                                    onTap: () => Navigator.pop<DateTime>(context, h.day),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }
}
