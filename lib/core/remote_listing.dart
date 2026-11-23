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
    );
