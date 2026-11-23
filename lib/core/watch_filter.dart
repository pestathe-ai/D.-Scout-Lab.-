import 'catalog.dart';
import 'text_utils.dart';

/// Parole che indicano un orologio (italiano, inglese, spagnolo, francese, tedesco).
const watchWords = [
  'orologio', 'orologi', 'watch', 'watches', 'reloj', 'relojes', 'montre', 'uhr',
  'armbanduhr', 'cronografo', 'chronograph', 'cronograph', 'automatico', 'automatic',
  'carica manuale', 'quarzo', 'quartz', 'eco-drive', 'eco drive', 'kinetic',
  'quadrante', 'dial', 'esfera', 'lunetta', 'ghiera', 'bezel', 'calibro', 'movimento',
  'subacqueo', 'diver', 'chronometer', 'cronometro', 'solare', 'solar', 'gmt',
  'polso', 'acciaio', 'cassa', 'zaffiro',
];

/// Parole che indicano chiaramente che NON è un orologio da polso.
const nonWatchWords = [
  // integratori e salute
  'omega 3', 'omega-3', 'omega3', 'integratore', 'integratori', 'capsule', 'perle',
  'olio di pesce', 'compresse',
  // auto e moto
  'opel', 'centralina', 'centralita', 'cerchi', 'pneumatici', 'ricambi auto',
  'tappetini', 'alfombrillas',
  // elettronica e casa
  'stampante', 'calcolatrice', 'macchina da cucire', 'telescopio', 'binocolo',
  'televisore', 'tv led', 'cartuccia', 'toner', 'autoradio', 'casse', 'tweeter',
  'sveglia da comodino', 'orologio da parete', 'orologio da muro',
  'orologio da tavolo', 'pendola', 'pendolo', 'cucù',
  // giochi e collezionismo non orologi
  'pokemon', 'pokémon', 'funko', 'videogioco', 'nintendo', 'playstation', 'figurine',
  'manifesto', 'poster', 'pubblicità', 'publicidad', 'anuncio publicitario',
  'locandina', 'rivista',
  // abbigliamento
  'scarpe', 'giacca', 'felpa', 'maglietta', 't-shirt', 'pantaloni', 'zaino', 'borsa',
  'occhiali', 'profumo', 'cappello',
];

/// true = è un orologio, false = sicuramente no, null = non si capisce.
bool? classifyWatch(String rawText) {
  final text = normalize(rawText);
  if (firstTerm(text, nonWatchWords) != null) return false;
  if (firstTerm(text, watchWords) != null) return true;
  for (final m in models) {
    if (firstTerm(text, m.aliases) != null) return true;
  }
  // Referenze tipo "6139-7101", "SKX007", "311.30.42.30"
  if (RegExp(r'\b([a-z]{2,4}\d{3,4}[a-z]?\d?|\d{4}-\d{4}|\d{3}\.\d{2,3}\.\d{2})\b')
      .hasMatch(text)) {
    return true;
  }
  return null;
}
