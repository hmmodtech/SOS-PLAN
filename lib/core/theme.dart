
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
