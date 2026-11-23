import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:scout_lab/core/parsers.dart';
import 'package:scout_lab/core/remote_listing.dart';
import 'package:scout_lab/core/valuator.dart';

void main() {
  test('Subito: legge __NEXT_DATA__ (features come lista o mappa)', () {
    final data = {
      'props': {
        'pageProps': {
          'initialState': {
            'items': {
              'list': [
                {
                  'item': {
                    'urn': 'id:ad:1',
                    'subject': 'Omega Seamaster 300m 2531.80',
                    'body': 'Revisionato, scatola e garanzia',
                    'urls': {'default': 'https://www.subito.it/a/1.htm'},
                    'features': [
                      {'uri': '/price', 'values': [{'key': '1500', 'value': '1.500 €'}]}
                    ],
                    'geo': {'town': {'value': 'Milano'}},
                  }
                },
                {
                  'item': {
                    'urn': 'id:ad:2',
                    'subject': 'Seiko 5',
                    'urls': {'default': 'https://www.subito.it/a/2.htm'},
                    'features': {
                      '/price': {'values': [{'key': '90', 'value': '90 €'}]}
                    },
                  }
                },
              ]
            }
          }
        }
      }
    };
    final html =
        '<html><script id="__NEXT_DATA__" type="application/json">${jsonEncode(data)}</script></html>';
    final items = parseSubitoHtml(html);
    expect(items.length, 2);
    expect(items[0].price, 1500);
    expect(items[0].place, 'Milano');
    expect(items[1].price, 90);
    expect(items[0].url, 'https://www.subito.it/a/1.htm');
  });

  test('Subito: pagina senza dati = errore chiaro', () {
    expect(() => parseSubitoHtml('<html></html>'), throwsFormatException);
  });

  test('eBay: Browse API', () {
    final data = {
      'total': 1,
      'itemSummaries': [
        {
          'itemId': 'v1|1|0',
          'title': 'Rado Captain Cook automatico',
          'price': {'value': '850.00', 'currency': 'EUR'},
          'condition': 'Usato',
          'itemWebUrl': 'https://www.ebay.it/itm/1',
          'buyingOptions': ['FIXED_PRICE'],
        }
      ]
    };
    final items = parseEbay(data);
    expect(items.single.price, 850);
    expect(parseEbay({'total': 0}), isEmpty);
  });

  test('dal sito alla valutazione', () {
    const item = RemoteItem(
        source: 'eBay',
        id: '9',
        title: 'Rado Captain Cook automatico',
        price: 850,
        url: 'https://www.ebay.it/itm/9');
    final l = listingFromRemote(item);
    expect(l.id, 'eBay:9');
    final v = const Valuator().evaluate(l);
    expect(v.model?.id, 'rado_captaincook');
    expect(v.verdict, Verdict.affare);
  });

  test('priceOf', () {
    expect(priceOf('120.0'), 120);
    expect(priceOf({'amount': '45.5'}), 45.5);
    expect(priceOf('1.200 €'), 1200);
    expect(priceOf(null), isNull);
  });
}
