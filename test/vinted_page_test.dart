import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_lab/core/valuator.dart';
import 'package:scout_lab/core/vinted_page.dart';

void main() {
  test('legge i box di Vinted (titolo con marca e prezzo)', () {
    final msg = jsonEncode([
      {
        'id': '123',
        'url': 'https://www.vinted.it/items/123-seiko-skx007',
        'title':
            'Seiko SKX007 automatico, marca: Seiko, condizioni: Ottime, 180,00 €, 189,70 € include la Protezione acquisti',
        'text': 'Seiko\n180,00 €',
      },
      {
        'id': '124',
        'url': 'https://www.vinted.it/items/124',
        'title': 'Orologio, marca: Orient, condizioni: Buone, 60,00 €',
        'text': '',
      },
    ]);
    final l = parseVintedPage(msg, watchCategory: true);
    expect(l.length, 2);
    expect(l[0].id, 'Vinted:123');
    expect(l[0].price, 180);
    expect(l[0].siteBrand, 'Seiko');
    expect(l[0].title, 'Seiko SKX007 automatico');
    expect(l[0].isWatch, isTrue);
    const v = Valuator(enabledBrands: {'seiko'});
    expect(v.evaluate(l[0]).verdict, isNot(Verdict.nonPertinente));
    expect(v.evaluate(l[1]).verdict, Verdict.nonPertinente);
  });

  test('categoria scelta nei filtri', () {
    expect(vintedHasCategory('https://www.vinted.it/catalog?catalog[]=1904'), isTrue);
    expect(vintedHasCategory('https://www.vinted.it/catalog?search_text=seiko'), isFalse);
  });
}
