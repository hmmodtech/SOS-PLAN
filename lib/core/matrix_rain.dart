import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'theme.dart';

/// مطر رقمي خفيف على المعالج.
///
/// النسخة السابقة كانت تنسّق وترسم 14 حرفًا لكل عمود (مئات إلى آلاف من
/// TextPainter) كل 90ms داخل CustomPaint، وهذا يجمّد الجوالات المتوسطة.
/// هنا: عمود واحد لكل ~22px، 7 حروف كحد أقصى، معدّل تحديث 160ms، وتوقّف
/// كامل عند إخفاء التطبيق أو طلب تقليل الحركة.
const double _cell = 16.0;
const int _trail = 7;
const Duration _frame = Duration(milliseconds: 160);

const String _glyphs =
    'ｱｲｳｴｵｶｷｸｹｺﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉ0123456789ABCDEFZ';

class MatrixRain extends StatefulWidget {
  const MatrixRain({super.key});

  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain> with WidgetsBindingObserver {
  final Random _rnd = Random();
  final List<double> _heads = <double>[];
  final List<double> _speeds = <double>[];
  double _height = 0;
  int _tick = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_frame, (_) {
      if (!mounted) return;
      setState(() {
        _tick++;
        for (var i = 0; i < _heads.length; i++) {
          _heads[i] += _speeds[i];
          if (_heads[i] * _cell > _height + _trail * _cell) {
            _heads[i] = -_rnd.nextDouble() * 20;
          }
        }
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No frames are scheduled while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      if (_timer == null) _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the system "remove animations" accessibility setting.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return const ColoredBox(color: kBlack);
    }
    return LayoutBuilder(builder: (context, c) {
      _height = c.maxHeight;
      final cols = (c.maxWidth / _cell).ceil().clamp(0, 60);
      if (_heads.length != cols) {
        _heads
          ..clear()
          ..addAll(List.generate(cols, (_) => -_rnd.nextDouble() * 40));
        _speeds
          ..clear()
          ..addAll(List.generate(cols, (_) => 0.15 + _rnd.nextDouble() * 0.35));
      }
      return RepaintBoundary(
        child: Opacity(
          opacity: 0.28,
          child: CustomPaint(
            size: Size.infinite,
            isComplex: false,
            painter: _RainPainter(_heads, _tick),
          ),
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
    if (heads.isEmpty) return;
    // One reusable TextPainter for the whole frame.
    final painter = TextPainter(textDirection: TextDirection.ltr);

    for (var c = 0; c < heads.length; c++) {
      final head = heads[c].floor();
      for (var k = 0; k < _trail; k++) {
        final row = head - k;
        if (row < 0) continue;
        final y = row * _cell;
        if (y > size.height) break;
        final glyph = _glyphs[(c * 7 + row * 3 + tick) % _glyphs.length];
        painter.text = TextSpan(
          text: glyph,
          style: TextStyle(
            color: k == 0
                ? Colors.white
                : kGreen.withAlpha((200 * (1 - k / _trail)).round()),
            fontSize: 11,
          ),
        );
        painter.layout();
        painter.paint(canvas, Offset(c * _cell, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter old) => old.tick != tick;
}
