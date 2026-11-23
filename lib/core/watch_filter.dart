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
  'orologio da tavolo', 'pendola', 'pendolo', 'cucù', 'radiosveglia',
  // ottica e foto (binocoli Zenith, fotocamere Zenit)
  'prismatico', 'prismatici', 'binocolo', 'binocoli', 'cannocchiale', 'monocolo',
  'microscopio', 'fotocamera', 'macchina fotografica', 'reflex', 'obiettivo',
  'helios', 'zenit e', 'zenit-e', 'zenit 12', 'zenit et', 'pellicola',
  // ufficio e casa (pinzatrici Zenith, radio, TV)
  'pinzatrice', 'cucitrice', 'spillatrice', 'punti metallici', 'radio d\'epoca',
  'radio a valvole', 'radiolina', 'giradischi', 'proiettore', 'macchina per caffè',
  // orologi da tasca
  'orologio da tasca', 'da taschino', 'pocket watch', 'reloj de bolsillo', 'cipollone',
  // contenitori e accessori venduti da soli
  'porta orologi', 'portaorologi', 'watch box', 'watch winder', 'carica orologi',
  'caricatore per orologi', 'scatola per orologi', 'scatola vuota', 'solo scatola',
  'solo box', 'box vuoto', 'senza orologio', 'orologio non incluso', 'solo garanzia',
  'solo certificato', 'estuche', 'expositor',
  // giochi e collezionismo non orologi
  'pokemon', 'pokémon', 'funko', 'videogioco', 'nintendo', 'playstation', 'figurine',
  'manifesto', 'poster', 'pubblicità', 'publicidad', 'anuncio publicitario',
  'locandina', 'rivista',
  // abbigliamento
  'scarpe', 'giacca', 'felpa', 'maglietta', 't-shirt', 'pantaloni', 'zaino', 'borsa',
  'occhiali', 'profumo', 'cappello',
];

/// Titoli che iniziano così parlano di un contenitore, non di un orologio.
const boxTitleStarts = [
  'scatola', 'scatole', 'box', 'astuccio', 'custodia', 'cofanetto', 'caja', 'cajas',
  'estuche', 'garanzia', 'certificato', 'libretto', 'manuale', 'cinturino',
  'cinturini', 'bracciale per', 'correa', 'catalogo', 'brochure', 'espositore',
];

/// Marche di orologi che l'app non segue: se il titolo parla di una di
/// queste prima che di una marca seguita, l'annuncio è di un'altra marca.
const otherBrands = [
  'rolex', 'tudor', 'longines', 'tissot', 'breitling', 'tag heuer', 'heuer', 'iwc',
  'jaeger', 'cartier', 'patek', 'audemars', 'vacheron', 'panerai', 'hublot',
  'minerva', 'eterna', 'baume', 'universal geneve', 'universal genève', 'doxa',
  'oris', 'hamilton', 'certina', 'mido', 'swatch', 'orient', 'casio', 'g-shock',
  'sector', 'breil', 'festina', 'fossil', 'lorenz', 'philip watch', 'vetta',
  'eberhard', 'girard', 'blancpain', 'chopard', 'bulova', 'junghans', 'sinn',
  'nomos', 'glashutte', 'glashütte', 'poljot', 'vostok', 'tissot',
];

/// Prima marca (seguita o no) citata nel titolo: restituisce il nome di
/// una marca NON seguita se compare prima di quelle seguite.
String? otherBrandFirst(String rawTitle) {
  final title = normalize(rawTitle);
  int pos(String term) {
    final m = RegExp('(^|[^a-z0-9])${RegExp.escape(term)}(?=\$|[^a-z0-9])')
        .firstMatch(title);
    return m == null ? -1 : m.start;
  }

  var followed = 1 << 30;
  for (final b in brands) {
    for (final n in [...b.names, ...b.misspellings]) {
      final p = pos(n);
      if (p >= 0 && p < followed) followed = p;
    }
  }
  String? other;
  var otherPos = 1 << 30;
  for (final o in otherBrands) {
    final p = pos(o);
    if (p >= 0 && p < otherPos) {
      otherPos = p;
      other = o;
    }
  }
  if (other == null) return null;
  // "Omega x Swatch": la marca seguita viene prima, va bene.
  return otherPos < followed ? other : null;
}

/// true = è un orologio da polso, false = sicuramente no, null = non si capisce.
/// [title], se noto, permette di riconoscere scatole e accessori.
bool? classifyWatch(String rawText, {String title = ''}) {
  final text = normalize(rawText);
  final t = normalize(title);
  if (t.isNotEmpty) {
    for (final start in boxTitleStarts) {
      if (t == start || t.startsWith('$start ')) return false;
    }
  }
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

/// Sinonimi di marche non seguite, per non contarle due volte.
const _otherAlias = {
  'tag heuer': 'heuer',
  'universal genève': 'universal geneve',
  'glashütte': 'glashutte',
  'g-shock': 'casio',
};

class BrandMention {
  /// id della marca seguita (es. "seiko") oppure nome dell'altra marca.
  final String key;
  final int pos;
  final bool followed;
  const BrandMention(this.key, this.pos, this.followed);
}

/// Tutte le marche citate nel testo, una volta ciascuna, in ordine di comparsa.
List<BrandMention> brandMentions(String rawText) {
  final text = normalize(rawText);
  int pos(String term) {
    final m = RegExp('(^|[^a-z0-9])${RegExp.escape(term)}(?=\$|[^a-z0-9])')
        .firstMatch(text);
    return m == null ? -1 : m.start;
  }

  final found = <String, BrandMention>{};
  for (final b in brands) {
    for (final n in [...b.names, ...b.misspellings]) {
      final p = pos(n);
      if (p >= 0 && (found[b.id] == null || p < found[b.id]!.pos)) {
        found[b.id] = BrandMention(b.id, p, true);
      }
    }
  }
  for (final o in otherBrands) {
    final key = _otherAlias[o] ?? o;
    final p = pos(o);
    if (p >= 0 && (found[key] == null || p < found[key]!.pos)) {
      found[key] = BrandMention(key, p, false);
    }
  }
  return found.values.toList()..sort((a, b) => a.pos.compareTo(b.pos));
}

/// Marca vera dell'annuncio.
/// - Se il sito indica la marca scelta dal venditore, vale quella.
/// - Altrimenti conta la prima marca del titolo; un titolo con 3 o più marche
///   diverse è un elenco di parole chiave.
/// - Se il titolo non ne cita, la descrizione deve citarne una sola.
({Brand? brand, String? misspelling, String? reason}) resolveBrand({
  required String title,
  required String body,
  String? siteBrand,
}) {
  ({Brand? brand, String? misspelling, String? reason}) followedBrand(
      String id, String fromText) {
    final b = brandById(id)!;
    final t = normalize(fromText);
    final miss = firstTerm(t, b.names) == null ? firstTerm(t, b.misspellings) : null;
    return (brand: b, misspelling: miss, reason: null);
  }

  final sb = siteBrand == null ? '' : normalize(siteBrand);
  const generic = ['altro', 'altre marche', 'altra marca', 'other', 'nessuna', 'non specificata'];
  if (sb.isNotEmpty && !generic.contains(sb)) {
    final m = brandMentions(sb);
    if (m.isNotEmpty && m.first.followed) return followedBrand(m.first.key, title);
    return (
      brand: null,
      misspelling: null,
      reason: 'Il venditore indica la marca "$siteBrand"'
    );
  }

  final inTitle = brandMentions(title);
  if (inTitle.length >= 3) {
    return (
      brand: null,
      misspelling: null,
      reason: 'Titolo pieno di marche diverse: parole chiave'
    );
  }
  if (inTitle.isNotEmpty) {
    final first = inTitle.first;
    if (first.followed) return followedBrand(first.key, title);
    return (brand: null, misspelling: null, reason: 'È di un\'altra marca (${first.key})');
  }

  final inBody = brandMentions(body);
  if (inBody.isEmpty) {
    return (brand: null, misspelling: null, reason: 'Nessuna delle marche seguite');
  }
  if (inBody.length == 1 && inBody.first.followed) {
    return followedBrand(inBody.first.key, body);
  }
  if (inBody.length == 1) {
    return (brand: null, misspelling: null, reason: 'È di un\'altra marca (${inBody.first.key})');
  }
  return (
    brand: null,
    misspelling: null,
    reason: 'Marca non nel titolo e diverse marche nel testo: parole chiave'
  );
}
