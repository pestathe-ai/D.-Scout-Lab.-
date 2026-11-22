import 'package:flutter/material.dart';

import '../core/valuator.dart';

class Brandbook {
  static const blu = Color(0xFF1D3A8A);
  static const arancio = Color(0xFFF28C38);
  static const carta = Color(0xFFFFF8F0);
  static const inchiostro = Color(0xFF14213D);
  static const verde = Color(0xFF1E7B4F);
  static const rosso = Color(0xFFB3261E);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brandbook.blu,
    primary: Brandbook.blu,
    secondary: Brandbook.arancio,
    surface: Brandbook.carta,
    onSurface: Brandbook.inchiostro,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Sora',
    scaffoldBackgroundColor: Brandbook.carta,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Brandbook.carta,
      foregroundColor: Brandbook.inchiostro,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Sora',
        fontWeight: FontWeight.w800,
        fontSize: 22,
        color: Brandbook.blu,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Brandbook.blu.withValues(alpha: 0.10)),
      ),
    ),
  );
}

Color verdictColor(Verdict v) => switch (v) {
      Verdict.affare => Brandbook.verde,
      Verdict.interessante => Brandbook.arancio,
      Verdict.daVerificare => Brandbook.blu,
      Verdict.normale => Colors.grey.shade600,
      Verdict.scartato => Brandbook.rosso,
      Verdict.nonPertinente => Colors.grey.shade500,
    };

String verdictLabel(Verdict v) => switch (v) {
      Verdict.affare => 'Affare',
      Verdict.interessante => 'Interessante',
      Verdict.daVerificare => 'Da verificare',
      Verdict.normale => 'Prezzo normale',
      Verdict.scartato => 'Scartato',
      Verdict.nonPertinente => 'Non pertinente',
    };

String confidenceLabel(Confidence c) => switch (c) {
      Confidence.alta => 'Stima affidabile',
      Confidence.media => 'Stima media',
      Confidence.bassa => 'Stima incerta',
    };

String euro(double? v) {
  if (v == null) return '–';
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write('.');
    b.write(s[i]);
  }
  return '$b €';
}
