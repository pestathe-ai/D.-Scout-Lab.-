import 'watch_filter.dart';
import 'models.dart';
import 'parsers.dart';

/// Converte un risultato di ricerca in annuncio dell'app.
Listing listingFromRemote(RemoteItem i, {DateTime? at}) => Listing(
      id: '${i.source}:${i.id}',
      source: i.source,
      title: i.title,
      text: i.description,
      price: i.price,
      seenAt: at ?? DateTime.now(),
      url: i.url,
      imageUrl: i.imageUrl,
      place: i.place,
      isWatch: i.isWatch,
      siteBrand: i.siteBrand,
    );

/// Tiene solo gli orologi: si fida della categoria del sito e, se il sito
/// non la indica, chiede che il testo parli chiaramente di un orologio.
bool acceptRemote(RemoteItem i) {
  if (i.isWatch == false) return false;
  final c = classifyWatch('${i.title} ${i.description}', title: i.title);
  if (i.isWatch == true) return c != false;
  return c == true;
}
