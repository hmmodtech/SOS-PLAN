```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'data/seed.dart';
import 'screens/home_screen.dart';
import 'services/notifications.dart';
import 'services/security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_US');
  await initializeDateFormatting('ar');
  await appState.load();
  await Bell.init();
  if (!appState.seeded) {
    await Db.instance.replaceMission(missionFrom(DateTime.parse(appState.missionStart)));
    appState.markSeeded();
  }
  await Bell.resyncAll();
  runApp(const SosApp());
}

class SosApp extends StatelessWidget {
  const SosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'A.Jami SOS',
        theme: matrixTheme(),
        locale: Locale(appState.isArabic ? 'ar' : 'en'),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(appState.textScale),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: appState.matrixRain
                    ? const MatrixRain()
                    : const ColoredBox(color: kBlack),
              ),
              AppGate(child: child!),
            ],
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

/// بوابة القفل والطوارئ: تغطي التطبيق بالكامل عند الحاجة
class AppGate extends StatefulWidget {
  final Widget child;
  const AppGate({super.key, required this.child});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool _authing = false; // يمنع حلقة القفل أثناء ظهور نافذة البصمة

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (appState.locked) _unlock();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authing) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (appState.panicOnBackground) appState.setPanic(true);
      if (appState.appLock) appState.setLocked(true);
    } else if (state == AppLifecycleState.resumed && appState.locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authing) return;
    _authing = true;
    final ok = await unlockDevice();
    _authing = false;
    if (ok) {
      appState.setLocked(false);
      appState.setPanic(false);
    }
  }

  Future<void> _dismissPanic() async {
    if (appState.appLock) {
      await _unlock();
    } else {
      appState.setPanic(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => Stack(
        children: [
          widget.child,
          if (appState.panicActive)
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismissPanic,
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Text(
                    appState.t('Tap to resume', 'اضغط للمتابعة'),
                    style: const TextStyle(color: Colors.white10),
                  ),
                ),
              ),
            ),
          if (appState.locked && !appState.panicActive)
            Positioned.fill(
              child: Container(
                color: kBlack,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, color: kGreen, size: 56),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _unlock,
                      child: Text(appState.t('UNLOCK', 'فتح القفل')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```
