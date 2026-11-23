import 'models.dart';
import 'text_utils.dart';

/// App di annunci di cui l'app legge le notifiche delle ricerche salvate.
class Source {
  final String name;

  /// Parti del nome del pacchetto Android che identificano l'app.
  final List<String> packageHints;

  const Source(this.name, this.packageHints);
}

const sources = <Source>[
  Source('Subito', ['subito']),
  Source('Vinted', ['vinted']),
  Source('Catawiki', ['catawiki']),
  Source('eBay', ['ebay']),
  Source('Chrono24', ['chrono24']),
  Source('Kleinanzeigen', ['kleinanzeigen', 'ebay.kleinanzeigen']),
  Source('Facebook Marketplace', ['com.facebook.katana']),
];

/// Il nome dell'app di annunci, o null se il pacchetto non è seguito.
String? sourceForPackage(String packageName) {
  final p = packageName.toLowerCase();
  for (final s in sources) {
    if (s.packageHints.any(p.contains)) return s.name;
  }
  return null;
}

/// Trasforma una notifica in un annuncio. Restituisce null se la notifica
/// non viene da un'app seguita o non contiene niente di utile
/// (es. messaggi di chat, promemoria, riepiloghi senza prezzo né testo).
Listing? listingFromNotification({
  required String packageName,
  required String title,
  required String content,
  DateTime? at,
}) {
  final source = sourceForPackage(packageName);
  if (source == null) return null;
  final t = title.trim();
  final c = content.trim();
  if (t.isEmpty && c.isEmpty) return null;
  final both = '$t $c';
  final lower = normalize(both);
  // Messaggi tra utenti e notifiche di servizio non sono annunci.
  const noise = [
    'ti ha scritto', 'nuovo messaggio', 'ha inviato', 'messaggio da',
    'ha aggiunto ai preferiti', 'il tuo annuncio', 'la tua offerta',
    'pagamento', 'spedizione', 'ordine', 'recensione',
  ];
  if (noise.any(lower.contains) && parsePrice(both) == null) return null;
  return Listing(
    id: listingIdFor(source, both),
    source: source,
    title: t,
    text: c,
    price: parsePrice(both),
    seenAt: at ?? DateTime.now(),
  );
}
