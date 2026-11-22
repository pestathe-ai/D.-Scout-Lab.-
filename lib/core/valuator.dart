import 'catalog.dart';
import 'models.dart';
import 'text_utils.dart';

enum Confidence { alta, media, bassa }

enum Verdict {
  /// Prezzo chiaramente sotto mercato: vale la pena guardarlo subito.
  affare,

  /// Leggermente sotto mercato, o affare con stima poco sicura.
  interessante,

  /// Marca riconosciuta ma modello no, a prezzo basso: da guardare a mano.
  daVerificare,

  /// Prezzo nella norma o sopra.
  normale,

  /// Replica, solo ricambi, o prezzo troppo basso per essere vero.
  scartato,

  /// Nessuna delle marche seguite, o prezzo mancante.
  nonPertinente,
}

class Valuation {
  final Brand? brand;
  final WatchModel? model;
  final double? price;

  /// Valore di mercato stimato (fascia).
  final double? valueLow;
  final double? valueHigh;

  /// Margine stimato rivendendo al valore basso, al netto di costi.
  final double? margin;

  /// Sconto rispetto al valore medio stimato (0.3 = 30% sotto).
  final double? discount;
  final int score;
  final Confidence confidence;
  final Verdict verdict;
  final Liquidity? liquidity;

  /// Numero di prezzi nello storico usati per la stima.
  final int historyCount;

  /// Motivi leggibili (in italiano) che spiegano il risultato.
  final List<String> reasons;

  const Valuation({
    required this.brand,
    required this.model,
    required this.price,
    required this.valueLow,
    required this.valueHigh,
    required this.margin,
    required this.discount,
    required this.score,
    required this.confidence,
    required this.verdict,
    required this.liquidity,
    required this.historyCount,
    required this.reasons,
  });

  bool get isHot => verdict == Verdict.affare;
}

class Settings {
  /// Sconto minimo sul valore medio per parlare di affare.
  final double dealThreshold;
  final double shippingCost;

  /// Commissioni e costi di rivendita, in percentuale.
  final double resaleFee;

  const Settings({
    this.dealThreshold = 0.25,
    this.shippingCost = 15,
    this.resaleFee = 0.10,
  });
}

const redFlags = [
  'replica', 'aaa', 'clone', 'copia', 'falso', 'fake', 'homage', 'omaggio',
  'ispirato', 'in stile', 'tipo rolex', 'non originale', 'imitazione', 'aliexpress',
];

const partsOnly = [
  'solo cinturino', 'cinturino per', 'solo bracciale', 'bracciale per', 'scatola vuota',
  'solo scatola', 'box only', 'per ricambi', 'pezzi di ricambio', 'solo quadrante',
  'solo cassa', 'solo movimento', 'solo lancette', 'vetro zaffiro per', 'maglie per',
  'fibbia per',
];

const urgency = [
  'urgente', 'trasloco', 'eredità', 'eredita', 'ereditato', 'del nonno', 'di mio nonno',
  'del papà', 'di mio padre', 'svuoto', 'svuota', 'sgombero', 'cantina', 'soffitta',
  'vendo subito', 'prezzo affare', 'per necessità', 'causa inutilizzo',
];

const mystery = [
  'vecchio orologio', 'orologio vecchio', 'orologio antico', 'non so', 'non conosco',
  'non me ne intendo', 'trovato', 'come da foto', 'vedi foto',
];

const brokenTerms = ['non funziona', 'guasto', 'fermo', 'rotto', 'da riparare'];
const needsService = ['da revisionare', 'necessita revisione', 'da sistemare', 'perde tempo'];
const serviced = ['revisionato', 'appena revisionato', 'service', 'revisione fatta'];
const fullSet = [
  'full set', 'fullset', 'scatola e garanzia', 'box e papers', 'box and papers',
  'box & papers', 'corredo completo', 'con garanzia', 'scatola e documenti',
  'completo di scatola',
];
const unworn = ['mai indossato', 'nuovo', 'come nuovo', 'pellicole'];

class Valuator {
  final Settings settings;

  /// Prezzi osservati per modello (asking price degli annunci).
  final Map<String, List<double>> history;

  const Valuator({this.settings = const Settings(), this.history = const {}});

  /// Riconosce la marca, segnalando se è scritta male.
  static ({Brand brand, String? misspelling})? detectBrand(String text) {
    for (final b in brands) {
      if (firstTerm(text, b.names) != null) return (brand: b, misspelling: null);
    }
    for (final b in brands) {
      final m = firstTerm(text, b.misspellings);
      if (m != null) return (brand: b, misspelling: m);
    }
    return null;
  }

  /// Il modello con l'alias più lungo presente nel testo, per quella marca.
  static WatchModel? detectModel(String text, Brand brand) {
    WatchModel? best;
    var bestLen = 0;
    for (final m in models) {
      if (m.brandId != brand.id) continue;
      for (final a in m.aliases) {
        if (a.length > bestLen && containsTerm(text, a)) {
          best = m;
          bestLen = a.length;
        }
      }
    }
    return best;
  }

  Valuation evaluate(Listing listing) =>
      evaluateText('${listing.title} ${listing.text}', listing.price);

  Valuation evaluateText(String rawText, double? price) {
    // "di rado" (raramente) non è la marca Rado.
    final text = normalize(rawText).replaceAll('di rado', 'di_raramente');
    final reasons = <String>[];

    final found = detectBrand(text);
    if (found == null) {
      return _result(
        price: price,
        verdict: Verdict.nonPertinente,
        reasons: ['Nessuna delle marche seguite'],
      );
    }
    final brand = found.brand;
    final model = detectModel(text, brand);

    final flag = firstTerm(text, redFlags);
    if (flag != null) {
      return _result(
        brand: brand,
        model: model,
        price: price,
        verdict: Verdict.scartato,
        reasons: ['Possibile replica ("$flag")'],
      );
    }
    final parts = firstTerm(text, partsOnly);
    if (parts != null && model == null) {
      return _result(
        brand: brand,
        price: price,
        verdict: Verdict.scartato,
        reasons: ['Sembra un ricambio o un accessorio ("$parts")'],
      );
    }
    if (price == null) {
      return _result(
        brand: brand,
        model: model,
        verdict: Verdict.nonPertinente,
        reasons: ['Prezzo non trovato nel testo'],
      );
    }

    // ---- Valore di base ----
    double baseLow;
    double baseHigh;
    var confidence = Confidence.bassa;
    var historyCount = 0;
    if (model != null) {
      baseLow = model.low;
      baseHigh = model.high;
      confidence = Confidence.media;
      reasons.add('Riconosciuto: ${model.name}');
      final h = history[model.id] ?? const <double>[];
      historyCount = h.length;
      final med = median(h);
      if (med != null && h.length >= 5) {
        // I prezzi richiesti sono più alti di quelli di vendita reale.
        final realized = med * 0.9;
        final w = h.length >= 15 ? 0.8 : 0.6;
        final mid = w * realized + (1 - w) * model.mid;
        final half = (model.high - model.low) / 2 * (h.length >= 15 ? 0.6 : 0.8);
        baseLow = mid - half;
        baseHigh = mid + half;
        if (h.length >= 15) confidence = Confidence.alta;
        reasons.add('Stima corretta con ${h.length} prezzi visti');
      } else {
        reasons.add('Stima dal catalogo (storico ancora scarso)');
      }
    } else {
      baseLow = brand.floor;
      baseHigh = brand.ceiling;
      reasons.add('${brand.name}: modello non riconosciuto');
    }

    // ---- Condizioni ----
    var factor = 1.0;
    var extraCost = 0.0;
    if (firstTerm(text, brokenTerms) != null) {
      factor *= 0.5;
      extraCost += brand.serviceCost;
      reasons.add('Non funzionante: valore dimezzato, più revisione');
    } else if (firstTerm(text, needsService) != null) {
      factor *= 0.85;
      extraCost += brand.serviceCost;
      reasons.add('Da revisionare: costo revisione incluso');
    } else if (firstTerm(text, serviced) != null) {
      factor *= 1.05;
      reasons.add('Revisionato');
    }
    if (firstTerm(text, fullSet) != null) {
      factor *= 1.10;
      reasons.add('Scatola e garanzia');
    }
    if (firstTerm(text, unworn) != null) {
      factor *= 1.05;
    }
    final low = baseLow * factor;
    final high = baseHigh * factor;
    final mid = (low + high) / 2;

    final discount = 1 - price / mid;
    final resale = low * (1 - settings.resaleFee);
    final margin = resale - price - settings.shippingCost - extraCost;

    // ---- Segnali extra ----
    var bonus = 0;
    if (found.misspelling != null) {
      bonus += 8;
      reasons.add('Marca scritta male ("${found.misspelling}"): meno concorrenza');
    }
    final urg = firstTerm(text, urgency);
    if (urg != null) {
      bonus += 5;
      reasons.add('Venditore con fretta ("$urg")');
    }
    if (firstTerm(text, mystery) != null) {
      bonus += 4;
      reasons.add('Annuncio vago: forse il venditore non sa cosa ha');
    }
    final liquidity = model?.liquidity;
    if (liquidity == Liquidity.alta) bonus += 4;
    if (liquidity == Liquidity.bassa) bonus -= 6;

    var score = (50 + discount * 100).round() + bonus;
    if (confidence == Confidence.bassa) score -= 10;
    score = score.clamp(0, 100);

    // ---- Verdetto ----
    Verdict verdict;
    final suspicious = model != null && discount > 0.75 && mid >= 500;
    if (suspicious) {
      verdict = Verdict.scartato;
      reasons.add('Prezzo troppo basso per essere vero: probabile truffa');
    } else if (model == null) {
      verdict = price < brand.floor * 1.2 ? Verdict.daVerificare : Verdict.normale;
    } else if (discount >= settings.dealThreshold && margin > 0) {
      verdict = Verdict.affare;
    } else if (discount >= settings.dealThreshold * 0.5) {
      verdict = Verdict.interessante;
    } else {
      verdict = Verdict.normale;
    }

    return Valuation(
      brand: brand,
      model: model,
      price: price,
      valueLow: low,
      valueHigh: high,
      margin: margin,
      discount: discount,
      score: score,
      confidence: confidence,
      verdict: verdict,
      liquidity: liquidity,
      historyCount: historyCount,
      reasons: reasons,
    );
  }

  Valuation _result({
    Brand? brand,
    WatchModel? model,
    double? price,
    required Verdict verdict,
    required List<String> reasons,
  }) =>
      Valuation(
        brand: brand,
        model: model,
        price: price,
        valueLow: null,
        valueHigh: null,
        margin: null,
        discount: null,
        score: 0,
        confidence: Confidence.bassa,
        verdict: verdict,
        liquidity: model?.liquidity,
        historyCount: 0,
        reasons: reasons,
      );
}
