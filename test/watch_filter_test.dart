import 'package:flutter_test/flutter_test.dart';
import 'package:scout_lab/core/parsers.dart';
import 'package:scout_lab/core/remote_listing.dart';
import 'package:scout_lab/core/valuator.dart';
import 'package:scout_lab/core/watch_filter.dart';

void main() {
  const v = Valuator();

  group('solo orologi', () {
    test('integratori Omega 3 esclusi', () {
      expect(classifyWatch('Omega 3 integratore 120 capsule'), isFalse);
      expect(v.evaluateText('Omega 3 integratore 120 capsule', 15).verdict,
          Verdict.nonPertinente);
    });
    test('ricambi Opel Omega esclusi', () {
      expect(classifyWatch('Opel Omega centralina 2.5 dti'), isFalse);
    });
    test('sveglie e orologi da parete esclusi', () {
      expect(classifyWatch('Seiko orologio da parete'), isFalse);
    });
    test('orologi riconosciuti dal testo', () {
      expect(classifyWatch('Seiko SKX007'), isTrue);
      expect(classifyWatch('Omega Seamaster automatico'), isTrue);
      expect(classifyWatch('Reloj Omega De Ville'), isTrue);
      expect(classifyWatch('Seiko 6139-7101 Helmet'), isTrue);
    });
    test('testo vago = non so', () {
      expect(classifyWatch('Citizen vendo'), isNull);
    });
  });

  group('categoria del sito', () {
    test('categoria non orologi scartata', () {
      const i = RemoteItem(source: 'Subito', id: '1', title: 'Omega Seamaster', isWatch: false);
      expect(acceptRemote(i), isFalse);
    });
    test('categoria orologi accettata anche con testo vago', () {
      const i = RemoteItem(source: 'Subito', id: '2', title: 'Citizen vendo', isWatch: true);
      expect(acceptRemote(i), isTrue);
    });
    test('senza categoria serve un testo chiaro', () {
      const vago = RemoteItem(source: 'eBay', id: '3', title: 'Citizen vendo');
      const chiaro = RemoteItem(source: 'eBay', id: '4', title: 'Citizen orologio Eco-Drive');
      expect(acceptRemote(vago), isFalse);
      expect(acceptRemote(chiaro), isTrue);
    });
    test('Subito: tipologia Orologi e gioielli', () {
      final items = parseSubitoJson({
        'list': [
          {
            'urn': 'a',
            'subject': 'Omega Constellation',
            'category': {'id': '16'},
            'urls': {'default': 'u'},
            'features': {
              '/clothing_type': {
                'values': [{'key': '12', 'value': 'Orologi e gioielli'}]
              },
              '/price': {'values': [{'key': '900'}]},
            },
          },
          {
            'urn': 'b',
            'subject': 'Macchina x carne',
            'category': {'id': '37'},
            'urls': {'default': 'u2'},
          },
        ]
      });
      expect(items[0].isWatch, isTrue);
      expect(items[1].isWatch, isFalse);
    });
    test('Wallapop: tassonomia Watches', () {
      final items = parseWallapop({
        'items': [
          {
            'id': 'w1',
            'title': 'Omega De Ville',
            'web_slug': 's1',
            'price': {'amount': 500},
            'taxonomy': [
              {'id': 18000, 'name': 'Collectibles & Art'},
              {'id': 10086, 'name': 'Watches'}
            ],
          },
          {
            'id': 'w2',
            'title': 'Pokémon Rubí Omega',
            'web_slug': 's2',
            'price': {'amount': 20},
            'taxonomy': [
              {'id': 24200, 'name': 'Technology & electronics'}
            ],
          },
        ]
      });
      expect(items[0].isWatch, isTrue);
      expect(items[1].isWatch, isFalse);
    });
  });

  test('MoonSwatch non è un affare a 200 €', () {
    final r = v.evaluateText('Omega x Swatch MoonSwatch Mission to Mars', 200);
    expect(r.model?.id, 'omega_moonswatch');
    expect(r.verdict, isNot(Verdict.affare));
    expect(r.verdict, isNot(Verdict.daVerificare));
  });

  test('cinturino in dotazione non scarta l\'orologio', () {
    final r = v.evaluateText('Seiko automatico con cinturino in pelle', 50);
    expect(r.verdict, isNot(Verdict.scartato));
  });

  test('prezzo simbolico e Seiko Mod scartati', () {
    expect(v.evaluateText('Seiko 5 automatic vintage 1981', 9).verdict,
        Verdict.scartato);
    expect(v.evaluateText('Seiko Mod Joker NH35 40mm', 159).verdict,
        anyOf(Verdict.scartato, Verdict.nonPertinente));
  });

  group('Zenith e scatole', () {
    void notWatch(String title, [String body = '', double price = 120]) {
      final r = v.evaluateText('$title $body', price, title: title);
      expect(r.verdict, Verdict.nonPertinente, reason: title);
    }

    test('ottica, foto e ufficio esclusi', () {
      notWatch('Binocolo Zenith 7x50 prismatico');
      notWatch('Zenith prismatici 8x30 con custodia');
      notWatch('Zenit E con obiettivo Helios 44');
      notWatch('Pinzatrice Zenith 548');
      notWatch('Zenith 10x50', 'ottimo stato, lenti pulite'); // non si capisce
    });

    test('scatole e accessori esclusi', () {
      notWatch('Scatola Zenith originale', 'per El Primero');
      notWatch('Box Omega Speedmaster', 'con garanzia');
      notWatch('Astuccio Rado');
      notWatch('Cofanetto Seiko vuoto');
      notWatch('Porta orologi in pelle', 'per Omega e Zenith');
    });

    test('altre marche e orologi da tasca esclusi', () {
      notWatch('Rolex Daytona Zenith', 'quadrante champagne', 14000);
      notWatch('Cronometro Minerva, omega longines zenith heuer');
      notWatch('Orologio da tasca Zenith', '', 180);
    });

    test('orologi veri tenuti', () {
      final a = v.evaluateText('Zenith El Primero full set con scatola', 2950,
          title: 'Zenith El Primero full set');
      expect(a.verdict, isNot(Verdict.nonPertinente));
      final b = v.evaluateText('Zenith AutoSport ref. 2552PC anni 70', 450,
          title: 'Zenith AutoSport.');
      expect(b.verdict, isNot(Verdict.nonPertinente));
      final c = v.evaluateText('Omega x Swatch MoonSwatch', 220,
          title: 'Omega x Swatch MoonSwatch');
      expect(c.verdict, isNot(Verdict.nonPertinente));
    });

    test('categoria orologi del sito accetta testo vago', () {
      final r = v.evaluateText('Citizen vendo', 120,
          title: 'Citizen vendo', siteSaysWatch: true);
      expect(r.verdict, isNot(Verdict.nonPertinente));
    });
  });
}
