import 'stats_screen.dart';
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../services/calendar_sync.dart';
import '../services/export.dart';
import '../services/notifications.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  String s(String en, String ar) => appState.t(en, ar);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Private tasks are never sent to calendars or exported.
  Future<List<Task>> _shareable() async {
    final all = await Db.instance.tasks();
    return all.where((t) => !t.isPrivate).toList();
  }

  // Runs a long action with a progress bar and shows the result.
  // Errors are shown generically; details are never printed or logged.
  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final msg = await action();
      _snack(msg);
    } catch (_) {
      _snack(s(
        'Action failed. Check your connection and try again.',
        'فشلت العملية. تحقّق من الاتصال وجرّب مرة ثانية.',
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setNotifs(bool v) async {
    setState(() {
      appState.setNotifs(v);
    });
    await Bell.resyncAll();
  }

  Future<void> _setBriefing(bool v) async {
    setState(() {
      appState.setBriefing(v);
    });
    await Bell.resyncAll();
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          text,
          style: const TextStyle(
            color: kGreen,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _card(Widget child) => Card(color: Colors.transparent, child: child);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(s('Settings', 'الإعدادات')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(color: kGreen),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ---------- Appearance ----------
                  _header(s('APPEARANCE', 'المظهر')),
                  _card(Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s('Card and day transparency', 'شفافية البطاقات والأيام')}: '
                          '${(appState.cardOpacity * 100).round()}%',
                        ),
                        Slider(
                          value: appState.cardOpacity,
                          min: 0.3,
                          max: 1.0,
                          divisions: 14,
                          onChanged: (v) {
                            setState(() {
                              appState.setOpacity(v);
                            });
                          },
                        ),
                      ],
                    ),
                  )),
                  _card(Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s('Text size', 'حجم الخط')}: '
                          '${(appState.textScale * 100).round()}%',
                        ),
                        Slider(
                          value: appState.textScale,
                          min: 0.8,
                          max: 1.4,
                          divisions: 6,
                          onChanged: (v) {
                            setState(() {
                              appState.setTextScale(v);
                            });
                          },
                        ),
                      ],
                    ),
                  )),
                  _card(SwitchListTile(
                    secondary: const Icon(Icons.grain, color: kGreen),
                    title: Text(s('Matrix rain background', 'خلفية المطر الرقمي')),
                    value: appState.matrixRain,
                    onChanged: (v) {
                      setState(() {
                        appState.setRain(v);
                      });
                    },
                  )),
                  _card(SwitchListTile(
                    secondary: const Icon(Icons.translate, color: kGreen),
                    title: Text(s('Arabic language', 'اللغة العربية')),
                    subtitle: Text(s('Off = English', 'مغلق = إنجليزي')),
                    value: appState.isArabic,
                    onChanged: (v) {
                      setState(() {
                        appState.setArabic(v);
                      });
                    },
                  )),

                  // ---------- Notifications ----------
                  _header(s('NOTIFICATIONS', 'الإشعارات')),
                  _card(SwitchListTile(
                    secondary: const Icon(Icons.notifications, color: kGreen),
                    title: Text(s('Task bell reminders', 'تذكيرات الجرس للمهام')),
                    value: appState.notificationsOn,
                    onChanged: (v) => _setNotifs(v),
                  )),
                  _card(SwitchListTile(
                    secondary: const Icon(Icons.wb_sunny_outlined, color: kGreen),
                    title: Text(s('Morning briefing (07:30)', 'الملخص الصباحي (07:30)')),
                    value: appState.morningBriefing,
                    onChanged: (v) => _setBriefing(v),
                  )),
                  _card(ListTile(
                    leading: const Icon(Icons.send, color: kGreen),
                    title: Text(s('Send test notification', 'إرسال إشعار تجريبي')),
                    onTap: () => _run(() async {
                      await Bell.test();
                      return s('Test notification sent', 'تم إرسال إشعار تجريبي');
                    }),
                  )),

                  // ---------- Security ----------
                  _header(s('SECURITY', 'الأمان')),
                  _card(SwitchListTile(
                    secondary: const Icon(Icons.fingerprint, color: kGreen),
                    title: Text(s('Lock app with fingerprint or PIN', 'قفل التطبيق ببصمة أو رمز')),
                    subtitle: Text(s(
                      'Locks when you leave the app',
                      'يقفل لما تخرج من التطبيق',
                    )),
                    value: appState.appLock,
                    onChanged: (v) {
                      setState(() {
                        appState.setLock(v);
                      });
                    },
                  )),
                  _card(SwitchListTile(
                    secondary: const Icon(Icons.shield_outlined, color: kGreen),
                    title: Text(s('Panic screen when leaving app', 'شاشة الطوارئ عند الخروج')),
                    subtitle: Text(s(
                      'Shows a black screen in recents',
                      'تظهر شاشة سوداء في قائمة التطبيقات',
                    )),
                    value: appState.panicOnBackground,
                    onChanged: (v) {
                      setState(() {
                        appState.setPanicBg(v);
                      });
                    },
                  )),

                  // ---------- Calendars ----------
                  _header(s('CALENDARS (PUSH ONLY)', 'التقويمات (إرسال فقط)')),
                  _card(ListTile(
                    leading: const Icon(Icons.calendar_month, color: kGreen),
                    title: Text(s('Sync to Google Calendar', 'مزامنة مع تقويم Google')),
                    subtitle: Text(s(
                      'Private tasks are never sent',
                      'المهام الخاصة ما بتنرسل أبداً',
                    )),
                    onTap: () => _run(() async {
                      final n = await GoogleCal.sync(await _shareable());
                      return s(
                        'Synced $n tasks to Google Calendar',
                        'تمت مزامنة $n مهمة مع تقويم Google',
                      );
                    }),
                  )),
                  _card(ListTile(
                    leading: const Icon(Icons.event_note, color: kGreen),
                    title: Text(s('Sync to Microsoft 365', 'مزامنة مع Microsoft 365')),
                    subtitle: Text(s(
                      'Private tasks are never sent',
                      'المهام الخاصة ما بتنرسل أبداً',
                    )),
                    onTap: () => _run(() async {
                      final n = await MsCal.sync(await _shareable());
                      return s(
                        'Synced $n tasks to Microsoft 365',
                        'تمت مزامنة $n مهمة مع Microsoft 365',
                      );
                    }),
                  )),
                  _header(s('REPORTS', 'التقارير')),
                  _card(ListTile(
                  leading: const Icon(Icons.bar_chart, color: kGreen),
                  title: Text(s('Completion reports', 'تقارير الإنجاز')),
                  trailing: const Icon(Icons.chevron_right, color: kDimGreen),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  ),
                )),

                  // ---------- Data ----------
                  _header(s('DATA', 'البيانات')),
                  _card(ListTile(
                    leading: const Icon(Icons.event_available, color: kGreen),
                    title: Text(s('Export calendar (.ics)', 'تصدير التقويم (.ics)')),
                    subtitle: Text(s(
                      'Opens in Google Calendar or Outlook',
                      'بيفتح في Google Calendar أو Outlook',
                    )),
                    onTap: () => _run(() async {
                      final tasks = await _shareable();
                      await shareFile('sos_calendar.ics', toIcs(tasks), 'text/calendar');
                      return s('Calendar file ready', 'ملف التقويم جاهز');
                    }),
                  )),
                  _card(ListTile(
                    leading: const Icon(Icons.table_chart_outlined, color: kGreen),
                    title: Text(s('Export tasks (.csv)', 'تصدير المهام (.csv)')),
                    onTap: () => _run(() async {
                      final tasks = await _shareable();
                      await shareFile('sos_tasks.csv', toCsv(tasks), 'text/csv');
                      return s('CSV file ready', 'ملف CSV جاهز');
                    }),
                  )),
                  _card(ListTile(
                    leading: const Icon(Icons.backup, color: kGreen),
                    title: Text(s('Create backup (.json)', 'إنشاء نسخة احتياطية (.json)')),
                    onTap: () => _run(() async {
                      await exportBackup();
                      return s('Backup created', 'تم إنشاء النسخة الاحتياطية');
                    }),
                  )),
                  _card(ListTile(
                    leading: const Icon(Icons.restore, color: kGreen),
                    title: Text(s('Restore from backup', 'استعادة من نسخة احتياطية')),
                    onTap: () => _run(() async {
                      final ok = await importBackup();
                      if (!ok) {
                        return s('No file was imported', 'ما تم استيراد أي ملف');
                      }
                      await Bell.resyncAll();
                      return s('Backup restored', 'تمت استعادة النسخة الاحتياطية');
                    }),
                  )),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
