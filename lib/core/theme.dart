import 'package:flutter/material.dart';
import 'app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// A.Jami SOS — Sci-Fi HUD palette
//
//   backgrounds : deep navy / midnight blue, dark petrol for borders
//   signal      : neon cyan-green, aqua/teal gradients, soft bloom
//   text        : muted gray-blue, desaturated green for sub-headings
//
// The identifiers keep their historical names (kGreen …) because they are used
// across every screen, the widgets and the splash; only the values changed.
// ─────────────────────────────────────────────────────────────────────────────

/// Primary glow — neon cyan-green. Replaces the old matrix green.
const kGreen = Color(0xFF25F4C8);

/// Secondary / dim signal — teal.
const kDimGreen = Color(0xFF14B8CE);

/// Aqua blue, used for the cold end of the glow gradients.
const kAqua = Color(0xFF38BDF8);

/// Deepest background — midnight blue, near black in the corners.
const kBlack = Color(0xFF04070F);

/// Panel surface, slightly lighter than the background.
const kSurface = Color(0xFF0A1424);

/// Dark petrol used for borders and dividers.
const kPetrol = Color(0xFF1B3A55);

/// Long-form / secondary text: muted gray-blue.
const kMuted = Color(0xFF7C8FAB);

/// Sub-headings: desaturated green, readable without glowing.
const kMutedGreen = Color(0xFF6E9E8F);

const kRed = Color(0xFFFF5470);
const kAmber = Color(0xFFFFC15E);

/// The neon bloom gradient: aqua → cyan-green → pale mint.
const kGlowGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [kAqua, kGreen, Color(0xFFB6FFE9)],
);

/// Radial halo used behind big numbers and progress rings.
const kHaloGradient = RadialGradient(
  colors: [Color(0x5525F4C8), Color(0x0004070F)],
);

/// Text gradient for headlines (numbers, screen titles).
const kTextGlow = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFB6FFE9), kGreen, kAqua],
);

ThemeData matrixTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBlack,
      canvasColor: kBlack,
      colorScheme: const ColorScheme.dark(
        primary: kGreen,
        onPrimary: kBlack,
        secondary: kAqua,
        onSecondary: kBlack,
        surface: kSurface,
        onSurface: Color(0xFFD7E6F5),
        error: kRed,
        outline: kPetrol,
      ),
      dividerColor: kPetrol,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: kGreen,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: kGreen,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          shadows: kTextBloom,
        ),
      ),
      iconTheme: const IconThemeData(color: kGreen),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Color(0xFFD7E6F5)),
        bodySmall: TextStyle(color: kMuted),
        titleMedium: TextStyle(
          color: kGreen,
          fontWeight: FontWeight.w700,
          shadows: kTextBloom,
        ),
        labelSmall: TextStyle(color: kMutedGreen, letterSpacing: 1.1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x99101E33),
        isDense: true,
        hintStyle: const TextStyle(color: kMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPetrol),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPetrol),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGreen, width: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: kSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kPetrol),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kGreen,
        linearTrackColor: Color(0xFF12283D),
        circularTrackColor: Color(0xFF12283D),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? kGreen : kMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kGreen.withAlpha(70)
              : kPetrol,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? kGreen
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(kBlack),
        side: const BorderSide(color: kPetrol, width: 1.6),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: kSurface,
        contentTextStyle: TextStyle(color: Color(0xFFD7E6F5)),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: kSurface),
    );

/// Soft neon bloom applied to glowing text.
const List<Shadow> kTextBloom = [
  Shadow(color: Color(0x9925F4C8), blurRadius: 12),
  Shadow(color: Color(0x6625F4C8), blurRadius: 26),
];

/// Stronger bloom for hero numbers.
const List<Shadow> kTextBloomStrong = [
  Shadow(color: Color(0xCC25F4C8), blurRadius: 18),
  Shadow(color: Color(0x8825F4C8), blurRadius: 40),
  Shadow(color: Color(0x4438BDF8), blurRadius: 60),
];

/// بطاقة زجاجية. الشفافية تتحكم فيها من الإعدادات.
BoxDecoration glass({Color? border, bool glow = true}) => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          // Deep navy, slightly lit from the top-left like a HUD panel.
          Color.fromRGBO(12, 24, 42, appState.cardOpacity),
          Color.fromRGBO(6, 12, 24, appState.cardOpacity),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border ?? kPetrol),
      boxShadow: glow
          ? [
              BoxShadow(color: kGreen.withAlpha(20), blurRadius: 18, spreadRadius: 1),
              BoxShadow(color: kAqua.withAlpha(12), blurRadius: 34, spreadRadius: 2),
            ]
          : null,
    );

/// شريط تقدّم متوهّج (Ferozi gradient + halo).
class GlowBar extends StatelessWidget {
  final double value; // 0..1
  final double height;
  final Color? color;

  const GlowBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, c) => Stack(
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF12283D),
              borderRadius: BorderRadius.circular(height),
            ),
          ),
          if (v > 0)
            Container(
              height: height,
              width: c.maxWidth * v,
              decoration: BoxDecoration(
                gradient: color == null
                    ? kGlowGradient
                    : LinearGradient(colors: [color!.withAlpha(150), color!]),
                borderRadius: BorderRadius.circular(height),
                boxShadow: [
                  BoxShadow(
                    color: (color ?? kGreen).withAlpha(140),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// رقم/عنوان متوهّج.
class GlowText extends StatelessWidget {
  final String text;
  final double size;
  final FontWeight weight;
  final bool strong;

  const GlowText(
    this.text, {
    super.key,
    this.size = 16,
    this.weight = FontWeight.w800,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: kGreen,
        shadows: strong ? kTextBloomStrong : kTextBloom,
      ),
    );
  }
}

/// عنوان قسم فرعي: أخضر باهت بدون توهج.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: kMutedGreen,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      );
}

Color catColor(String c) => switch (c) {
      'security' => kRed,
      'logistics' => kAmber,
      'child' => kAqua,
      'admin' => const Color(0xFFA78BFA),
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
