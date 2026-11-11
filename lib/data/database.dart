
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'models.dart';

/// قاعدة بيانات مشفرة (SQLCipher). المفتاح محفوظ في Keystore.
class Db {
  Db._();
  static final instance = Db._();
  static const _keyName = 'sos_db_key';
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    const store = FlutterSecureStorage();
    var key = await store.read(key: _keyName);
    if (key == null || key.isEmpty) {
      final rnd = Random.secure();
      key = base64Url.encode(List<int>.generate(32, (_) => rnd.nextInt(256)));
      try {
        await store.write(key: _keyName, value: key);
      } catch (_) {
        // Keystore unavailable: keep the generated key in memory for this run.
      }
    }
    return openDatabase(
      p.join(await getDatabasesPath(), 'sos_secure.db'),
      password: key,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title_en TEXT NOT NULL, title_ar TEXT,
            details_en TEXT, details_ar TEXT,
            date TEXT NOT NULL, remind_at TEXT,
            category TEXT NOT NULL,
            priority INTEGER NOT NULL DEFAULT 1,
            is_private INTEGER NOT NULL DEFAULT 0,
            recurrence TEXT NOT NULL DEFAULT 'none',
            checklist TEXT,
            is_mission INTEGER NOT NULL DEFAULT 0,
            google_id TEXT, ms_id TEXT,
            updated_at TEXT NOT NULL)''');
        await db.execute('''
          CREATE TABLE completions (
            task_id INTEGER NOT NULL, day TEXT NOT NULL,
            PRIMARY KEY (task_id, day))''');
        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            day TEXT NOT NULL, text TEXT NOT NULL)''');
      },
    );
  }

  // ---------- Tasks ----------
  Future<List<Task>> tasks() async {
    final db = await _database;
    final rows = await db.query('tasks', orderBy: 'date, remind_at');
    return rows.map(Task.fromMap).toList();
  }

  /// يضيف أو يعدّل ويرجع الـ id
  Future<int> saveTask(Task t) async {
    final db = await _database;
    final map = t.toMap();
    if (t.id == null) return db.insert('tasks', map);
    await db.update('tasks', map, where: 'id = ?', whereArgs: [t.id]);
    return t.id!;
  }

  Future<void> deleteTask(int id) async {
    final db = await _database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await db.delete('completions', where: 'task_id = ?', whereArgs: [id]);
  }

  Future<void> setSyncIds(int id, {String? google, String? ms}) async {
    final db = await _database;
    await db.update(
      'tasks',
      {if (google != null) 'google_id': google, if (ms != null) 'ms_id': ms},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setChecklistDone(int id, int index, bool done) async {
    final db = await _database;
    final row = (await db.query('tasks',
            columns: ['checklist'], where: 'id = ?', whereArgs: [id]))
        .first;
    final list = (jsonDecode(row['checklist'] as String? ?? '[]') as List)
        .cast<Map<String, dynamic>>();
    list[index]['d'] = done;
    await db.update(
      'tasks',
      {
        'checklist': jsonEncode(list),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// يستبدل مهام الخطة فقط (is_mission = 1)
  Future<void> replaceMission(List<Task> mission) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('tasks', where: 'is_mission = 1');
      for (final t in mission) {
        await txn.insert('tasks', t.toMap());
      }
    });
  }

  // ---------- Completions ----------
  Future<Set<String>> completionKeys() async {
    final db = await _database;
    final rows = await db.query('completions');
    return {for (final r in rows) '${r['task_id']}|${r['day']}'};
  }

  Future<void> setDone(int taskId, DateTime day, bool done) async {
    final db = await _database;
    if (done) {
      await db.insert(
        'completions',
        {'task_id': taskId, 'day': dayKey(day)},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      await db.delete('completions',
          where: 'task_id = ? AND day = ?', whereArgs: [taskId, dayKey(day)]);
    }
  }

  // ---------- Notes (memos) ----------
  Future<List<Note>> notesOn(DateTime day) async {
    final db = await _database;
    final rows = await db.query('notes',
        where: 'day = ?', whereArgs: [dayKey(day)], orderBy: 'id');
    return rows.map(Note.fromMap).toList();
  }

  Future<List<Note>> allNotes() async {
    final db = await _database;
    final rows = await db.query('notes', orderBy: 'day, id');
    return rows.map(Note.fromMap).toList();
  }

  Future<void> addNote(DateTime day, String text) async {
    final db = await _database;
    await db.insert('notes', {'day': dayKey(day), 'text': text});
  }

  Future<void> deleteNote(int id) async {
    final db = await _database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Backup / Restore ----------
  Future<Map<String, dynamic>> exportAll() async {
    final db = await _database;
    return {
      'version': 2,
      'tasks': await db.query('tasks'),
      'notes': await db.query('notes'),
      'completions': await db.query('completions'),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('notes');
      await txn.delete('completions');
      for (final r in data['tasks'] as List) {
        await txn.insert('tasks', Map<String, Object?>.from(r as Map));
      }
      for (final r in data['notes'] as List) {
        await txn.insert('notes', Map<String, Object?>.from(r as Map));
      }
      for (final r in data['completions'] as List) {
        await txn.insert('completions', Map<String, Object?>.from(r as Map));
      }
    });
  }
}

