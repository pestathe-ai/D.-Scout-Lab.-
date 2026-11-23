import 'package:flutter_test/flutter_test.dart';
import 'package:scout_lab/core/parsers.dart';
import 'package:scout_lab/core/valuator.dart';

void main() {
  const all = Valuator();
  const onlySeiko = Valuator(enabledBrands: {'seiko'});

  Verdict verdict(Valuator v, String title, String body,
          {double price = 150, String? siteBrand, bool? watch = true}) =>
      v
          .evaluateText('$title $body', price,
              title: title, siteSaysWatch: watch, siteBrand: siteBrand)
          .verdict;

  group('parole chiave di altre marche', () {
    test('titolo pieno di marche = scartato', () {
      expect(verdict(all, 'Orologio automatico seiko omega rolex citizen', ''),
          Verdict.nonPertinente);
    });
    test('marca vera nel titolo, Seiko solo citato nel testo', () {
      expect(verdict(all, 'Orient Mako automatico', 'simile al seiko skx'),
          Verdict.nonPertinente);
      expect(verdict(all, 'Invicta Pro Diver', 'tipo Seiko e Omega'),
          isNot(Verdict.affare));
    });
    test('titolo senza marca e testo con tante marche = scartato', () {
      expect(
          verdict(all, 'Orologio automatico vintage',
              'stile seiko omega longines tissot rolex'),
          Verdict.nonPertinente);
    });
    test('titolo senza marca ma testo con una sola marca seguita = ok', () {
      expect(verdict(all, 'Orologio cronografo vintage', 'Seiko 6139 originale', price: 300),
          isNot(Verdict.nonPertinente));
    });
    test('la marca scelta dal venditore vince sul testo', () {
      expect(verdict(all, 'Orologio subacqueo tipo Seiko', '', siteBrand: 'Orient'),
          Verdict.nonPertinente);
      expect(verdict(all, 'Orologio automatico vintage', '', siteBrand: 'Seiko', price: 90),
          isNot(Verdict.nonPertinente));
    });
    test('marca "Altro" ignorata', () {
      expect(verdict(all, 'Seiko 5 automatico', '', siteBrand: 'Altro', price: 90),
          isNot(Verdict.nonPertinente));
    });
    test('movimento Seiko su altre marche non conta', () {
      expect(
          verdict(all, 'Orologio uomo Pierre Bonnet Quarzo Seiko Nuovo', '',
              siteBrand: 'Altro', price: 49),
          Verdict.nonPertinente);
      expect(verdict(all, 'Orologio subacqueo automatico', 'movimento Seiko NH35A'),
          Verdict.nonPertinente);
      expect(verdict(all, 'Seiko 5 automatico', 'movimento Seiko 7S26', price: 90),
          isNot(Verdict.nonPertinente));
    });
    test('Omega x Swatch resta Omega', () {
      expect(verdict(all, 'Omega x Swatch MoonSwatch Mission to Mars', '', price: 200),
          isNot(Verdict.nonPertinente));
    });
  });

  group('marche selezionate', () {
    test('solo Seiko: Omega ignorato, Seiko valutato', () {
      expect(verdict(onlySeiko, 'Omega Seamaster 300m 2531.80', '', price: 1500),
          Verdict.nonPertinente);
      expect(verdict(onlySeiko, 'Seiko SKX007 urgente', '', price: 180),
          Verdict.affare);
    });
  });

  test('Subito: legge la marca scelta dal venditore', () {
    final items = parseSubitoJson({
      'list': [
        {
          'urn': 'x',
          'subject': 'Orologio tipo Seiko',
          'category': {'id': '16'},
          'urls': {'default': 'u'},
          'features': {
            '/fashion/brand': {
              'values': [{'key': '1', 'value': 'Orient'}]
            },
            '/price': {'values': [{'key': '120'}]},
          },
        }
      ]
    });
    expect(items.single.siteBrand, 'Orient');
  });
}
