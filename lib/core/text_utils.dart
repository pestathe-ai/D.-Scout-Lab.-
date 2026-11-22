/// Normalizza il testo: minuscolo, spazi singoli.
String normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Vero se [term] compare in [text] come parola (o sequenza di parole) intera.
/// Entrambi devono essere già normalizzati.
bool containsTerm(String text, String term) {
  if (term.isEmpty) return false;
  final escaped = RegExp.escape(term);
  return RegExp('(^|[^a-z0-9àèéìòù])$escaped(?=\$|[^a-z0-9àèéìòù])')
      .hasMatch(text);
}

/// Primo termine della lista presente nel testo, o null.
String? firstTerm(String text, Iterable<String> terms) {
  for (final t in terms) {
    if (containsTerm(text, t)) return t;
  }
  return null;
}

/// Tutti i termini della lista presenti nel testo.
List<String> allTerms(String text, Iterable<String> terms) =>
    [for (final t in terms) if (containsTerm(text, t)) t];

/// Estrae il prezzo in euro dal testo di un annuncio o di una notifica.
/// Riconosce "€ 1.200", "1.200 €", "1200€", "1.200,00 €", "EUR 300",
/// "300 euro", "€12.50". Restituisce null se non trova un prezzo plausibile.
double? parsePrice(String raw) {
  final text = raw.replaceAll(' ', ' ');
  const num = r'(\d{1,3}(?:[.,\s]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)';
  final patterns = <RegExp>[
    RegExp('(?:€|eur|euro)\\s*$num', caseSensitive: false),
    RegExp('$num\\s*(?:€|eur\\b|euro\\b)', caseSensitive: false),
  ];
  for (final p in patterns) {
    for (final m in p.allMatches(text)) {
      final v = _toNumber(m.group(1)!);
      if (v != null && v >= 5 && v <= 500000) return v;
    }
  }
  return null;
}

double? _toNumber(String s) {
  var t = s.replaceAll(' ', '');
  final lastDot = t.lastIndexOf('.');
  final lastComma = t.lastIndexOf(',');
  if (lastDot >= 0 && lastComma >= 0) {
    // Il separatore che compare per ultimo è quello dei decimali.
    if (lastComma > lastDot) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else if (lastComma >= 0) {
    final decimals = t.length - lastComma - 1;
    t = decimals == 3 ? t.replaceAll(',', '') : t.replaceAll(',', '.');
  } else if (lastDot >= 0) {
    final decimals = t.length - lastDot - 1;
    if (decimals == 3) t = t.replaceAll('.', '');
  }
  return double.tryParse(t);
}

/// Mediana di una lista di numeri (null se vuota).
double? median(List<double> values) {
  if (values.isEmpty) return null;
  final s = [...values]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}
