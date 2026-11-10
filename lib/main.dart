import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/app_state.dart';
import 'core/boot_log.dart';
import 'core/matrix_rain.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'data/seed.dart';
import 'screens/home_screen.dart';
import 'services/notifications.dart';
import 'services/security.dart';
import 'services/widget_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // A crash inside a plugin or an async task must never freeze the UI.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logBoot('UI error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logBoot('Uncaught: $error');
    return true; // handled: keep the app alive
  };

  // Never await anything before runApp(): a single failing plugin call there
  // leaves the user on a black screen and Android reports "not responding".
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
        home: const BootGate(),
      ),
    );
  }
}

/// Runs startup work *after* the first frame and always lands on a UI:
/// the home screen on success, or a readable error screen with a retry button.
class BootGate extends StatefulWidget {
  const BootGate({super.key});

  @override
  State<BootGate> createState() => _BootGateState();
}

class _BootGateState extends State<BootGate> {
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Let the splash paint before doing any I/O so the app never looks frozen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    setState(() => _error = null);
    try {
      await initializeDateFormatting('en_US');
      await initializeDateFormatting('ar');
      await appState.load();
      await _step('notifications', Bell.init);
      if (!appState.seeded) {
        await _step('seed', () async {
          await Db.instance
              .replaceMission(missionFrom(DateTime.parse(appState.missionStart)));
          appState.markSeeded();
        });
      }
      // Re-scheduling bells is the heaviest and most failure-prone step, so it
      // runs last and never blocks the UI.
      unawaited(_step('reminders', Bell.resyncAll));
      // Move memos typed on the home-screen widget into the database, then
      // publish a fresh snapshot for the widgets.
      unawaited(_step('widgets', () async {
        await WidgetBridge.pullWidgetMemos();
        await WidgetBridge.sync();
      }));
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  /// Runs one startup step; failures are recorded but do not abort startup.
  Future<void> _step(String name, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      logBoot('$name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const HomeScreen();
    if (_error != null) {
      return _BootError(
        message: _error!,
        log: bootLog,
        onRetry: _boot,
        onSkip: () => setState(() => _done = true),
      );
    }
    return const _Splash();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, color: kGreen, size: 64),
            const SizedBox(height: 20),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: kGreen,
                backgroundColor: kGreen.withAlpha(40),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'A.Jami SOS',
              style: TextStyle(color: kGreen.withAlpha(180), letterSpacing: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootError extends StatelessWidget {
  final String message;
  final List<String> log;
  final Future<void> Function() onRetry;
  final VoidCallback onSkip;

  const _BootError({
    required this.message,
    required this.log,
    required this.onRetry,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Startup error',
                style: TextStyle(color: kRed, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    [message, if (log.isNotEmpty) '--- log ---', ...log].join('\n'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: onSkip, child: const Text('Open anyway')),
            ],
          ),
        ),
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
    if (!mounted) return;
    if (ok) {
      appState.setLocked(false);
      appState.setPanic(false);
    } else {
      setState(() {}); // show the unlock button again
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
                    const SizedBox(height: 8),
                    // Escape hatch: never leave the user stuck behind a detector
                    // that keeps failing (e.g. no fingerprint enrolled).
                    TextButton(
                      onPressed: () {
                        appState.setLock(false);
                        appState.setLocked(false);
                      },
                      child: Text(
                        appState.t('Disable app lock', 'إيقاف قفل التطبيق'),
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
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
