/// Un annuncio visto dall'app (da una notifica o incollato a mano).
class Listing {
  final String id;
  final String source;
  final String title;
  final String text;
  final double? price;
  final DateTime seenAt;
  final bool dismissed;
  final String? url;
  final String? imageUrl;
  final String? place;

  const Listing({
    required this.id,
    required this.source,
    required this.title,
    required this.text,
    required this.price,
    required this.seenAt,
    this.dismissed = false,
    this.url,
    this.imageUrl,
    this.place,
  });

  Listing copyWith({bool? dismissed}) => Listing(
        id: id,
        source: source,
        title: title,
        text: text,
        price: price,
        seenAt: seenAt,
        dismissed: dismissed ?? this.dismissed,
        url: url,
        imageUrl: imageUrl,
        place: place,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        'title': title,
        'text': text,
        'price': price,
        'seenAt': seenAt.millisecondsSinceEpoch,
        'dismissed': dismissed,
        if (url != null) 'url': url,
        if (imageUrl != null) 'img': imageUrl,
        if (place != null) 'place': place,
      };

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'] as String,
        source: j['source'] as String? ?? 'manuale',
        title: j['title'] as String? ?? '',
        text: j['text'] as String? ?? '',
        price: (j['price'] as num?)?.toDouble(),
        seenAt: DateTime.fromMillisecondsSinceEpoch(
            (j['seenAt'] as num?)?.toInt() ?? 0),
        dismissed: j['dismissed'] as bool? ?? false,
        url: j['url'] as String?,
        imageUrl: j['img'] as String?,
        place: j['place'] as String?,
      );
}

/// Un prezzo osservato per un modello, per costruire lo storico.
class PricePoint {
  final String modelId;
  final double price;
  final DateTime at;
  final String listingId;

  const PricePoint(this.modelId, this.price, this.at, this.listingId);

  Map<String, dynamic> toJson() => {
        'm': modelId,
        'p': price,
        't': at.millisecondsSinceEpoch,
        'l': listingId,
      };

  factory PricePoint.fromJson(Map<String, dynamic> j) => PricePoint(
        j['m'] as String,
        (j['p'] as num).toDouble(),
        DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        j['l'] as String? ?? '',
      );
}

/// Identificativo stabile di un annuncio a partire dal testo.
String listingIdFor(String source, String text) {
  var h = 0x811c9dc5;
  for (final c in '$source|$text'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}
