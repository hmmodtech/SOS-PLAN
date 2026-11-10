
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'app_state.dart';

const kGreen = Color(0xFF00FF41);
const kDimGreen = Color(0xFF00B32C);
const kBlack = Color(0xFF000803);
const kRed = Color(0xFFFF3B3B);
const kAmber = Color(0xFFE8C84A);

ThemeData matrixTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xE6000803),
      colorScheme: const ColorScheme.dark(
        primary: kGreen,
        secondary: kDimGreen,
        surface: Color(0xFF031A08),
        error: kRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: kGreen,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: kGreen,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x66000000),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kGreen.withAlpha(70)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kGreen.withAlpha(70)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kGreen),
        ),
      ),
    );

/// بطاقة زجاجية. الشفافية تتحكم فيها من الإعدادات.
BoxDecoration glass({Color? border}) => BoxDecoration(
      color: Color.fromRGBO(3, 26, 8, appState.cardOpacity),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: border ?? kGreen.withAlpha(60)),
      boxShadow: [BoxShadow(color: kGreen.withAlpha(25), blurRadius: 12)],
    );

Color catColor(String c) => switch (c) {
      'security' => kRed,
      'logistics' => kAmber,
      'child' => const Color(0xFF4FC3F7),
      'admin' => const Color(0xFFB39DDB),
      _ => kGreen,
    };

String catLabel(String c) => switch (c) {
      'security' => appState.t('Security', 'الأمن'),
      'logistics' => appState.t('Logistics', 'اللوجستيات'),
      'child' => appState.t('Child Protection', 'حماية الطفل'),
      'admin' => appState.t('Admin', 'الإدارة'),
      _ => appState.t('General', 'عام'),
    };

String repeatLabel(String r) => switch (r) {
      'daily' => appState.t('Daily', 'يومياً'),
      'weekly' => appState.t('Weekly', 'أسبوعياً'),
      'monthly' => appState.t('Monthly', 'شهرياً'),
      _ => appState.t('Once', 'مرة واحدة'),
    };

// ---------- المطر الرقمي (Matrix rain) ----------
const _rainCell = 14.0;
const _glyphs = 'ｱｲｳｴｵｶｷｸｹｺﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉ0123456789ABCDEFZ';

class MatrixRain extends StatefulWidget {
  const MatrixRain({super.key});

  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain> {
  final _rnd = Random();
  final _heads = <double>[];
  final _speeds = <double>[];
  double _height = 0;
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      setState(() {
        _tick++;
        for (var i = 0; i < _heads.length; i++) {
          _heads[i] += _speeds[i];
          if (_heads[i] * _rainCell > _height + 14 * _rainCell) {
            _heads[i] = -_rnd.nextDouble() * 20;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _height = c.maxHeight;
      final cols = (c.maxWidth / _rainCell).ceil();
      if (_heads.length != cols) {
        _heads
          ..clear()
          ..addAll(List.generate(cols, (_) => -_rnd.nextDouble() * 40));
        _speeds
          ..clear()
          ..addAll(List.generate(cols, (_) => 0.2 + _rnd.nextDouble() * 0.5));
      }
      return Opacity(
        opacity: 0.35,
        child: CustomPaint(
          size: Size.infinite,
          painter: _RainPainter(_heads, _tick),
        ),
      );
    });
  }
}

class _RainPainter extends CustomPainter {
  final List<double> heads;
  final int tick;
  _RainPainter(this.heads, this.tick);

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var c = 0; c < heads.length; c++) {
      final head = heads[c].floor();
      for (var k = 0; k < 14; k++) {
        final row = head - k;
        if (row < 0) continue;
        final y = row * _rainCell;
        if (y > size.height) continue;
        final ch = _glyphs[(c * 7 + row * 3 + tick) % _glyphs.length];
        final color = k == 0
            ? Colors.white
            : kGreen.withAlpha((230 * (1 - k / 14)).round());
        tp.text = TextSpan(
          text: ch,
          style: TextStyle(color: color, fontSize: 12, fontFamily: 'monospace'),
        );
        tp.layout();
        tp.paint(canvas, Offset(c * _rainCell, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) => true;
}

