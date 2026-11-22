import 'package:flutter_test/flutter_test.dart';
import 'package:scout_lab/core/catalog.dart';
import 'package:scout_lab/core/sources.dart';
import 'package:scout_lab/core/text_utils.dart';
import 'package:scout_lab/core/valuator.dart';

void main() {
  group('parsePrice', () {
    test('formati italiani e internazionali', () {
      expect(parsePrice('Prezzo € 1.200'), 1200);
      expect(parsePrice('1.200,00 €'), 1200);
      expect(parsePrice('Seiko SKX007 - 350€'), 350);
      expect(parsePrice('EUR 300'), 300);
      expect(parsePrice('€12.50'), 12.5);
      expect(parsePrice('vendo a 300 euro trattabili'), 300);
      expect(parsePrice('1 200 €'), 1200);
    });
    test('la referenza non viene scambiata per prezzo', () {
      expect(parsePrice('Omega 311.30.42.30 € 4.500'), 4500);
    });
    test('nessun prezzo', () {
      expect(parsePrice('Seiko automatico come nuovo'), isNull);
    });
  });

  group('riconoscimento', () {
    test('parola intera', () {
      expect(containsTerm('grado di impermeabilità', 'rado'), isFalse);
      expect(containsTerm('rado diastar', 'rado'), isTrue);
    });
    test('marca scritta male', () {
      final r = Valuator.detectBrand(normalize('Omgea speedmaster'));
      expect(r?.brand.id, 'omega');
      expect(r?.misspelling, 'omgea');
    });
    test('alias più lungo vince', () {
      final b = brandById('omega')!;
      final m = Valuator.detectModel(normalize('omega seamaster de ville'), b);
      expect(m?.id, 'omega_vintage');
    });
  });

  group('valutazione', () {
    const v = Valuator();

    test('Seiko SKX sotto mercato con venditore di fretta è un affare', () {
      final r = v.evaluateText('Seiko SKX007 urgente causa trasloco', 180);
      expect(r.model?.id, 'seiko_skx');
      expect(r.verdict, Verdict.affare);
      expect(r.margin! > 0, isTrue);
    });

    test('prezzo assurdo su modello costoso = probabile truffa', () {
      final r = v.evaluateText('Omega Speedmaster Professional moonwatch', 900);
      expect(r.verdict, Verdict.scartato);
    });

    test('marche non seguite', () {
      final r = v.evaluateText('Rolex Submariner 16610', 6000);
      expect(r.verdict, Verdict.nonPertinente);
    });

    test('"di rado" non è Rado', () {
      final r = v.evaluateText('Tissot indossato di rado', 200);
      expect(r.verdict, Verdict.nonPertinente);
    });

    test('replica scartata', () {
      final r = v.evaluateText('Seiko SKX replica AAA', 40);
      expect(r.verdict, Verdict.scartato);
    });

    test('prezzo di mercato = normale', () {
      final r = v.evaluateText('Citizen Promaster NY0040 Fugu', 280);
      expect(r.verdict, Verdict.normale);
    });

    test('marca senza modello a prezzo basso = da verificare', () {
      final r = v.evaluateText('vecchio orologio Zenit del nonno', 150);
      expect(r.verdict, Verdict.daVerificare);
      expect(r.brand?.id, 'zenith');
    });

    test('non funzionante abbassa il valore', () {
      final ok = v.evaluateText('Seiko Alpinist SARB017', 400);
      final ko = v.evaluateText('Seiko Alpinist SARB017 non funziona', 400);
      expect(ko.valueLow! < ok.valueLow!, isTrue);
      expect(ko.verdict == Verdict.affare, isFalse);
    });

    test('lo storico corregge la stima', () {
      final h = Valuator(history: {'seiko_skx': List.filled(20, 200.0)});
      final r = h.evaluateText('Seiko SKX007', 150);
      expect(r.confidence, Confidence.alta);
      expect(r.historyCount, 20);
      final mid = (r.valueLow! + r.valueHigh!) / 2;
      expect(mid, closeTo(0.8 * 180 + 0.2 * 350, 0.01));
    });
  });

  group('notifiche', () {
    test('notifica Subito diventa annuncio', () {
      final l = listingFromNotification(
        packageName: 'it.subito',
        title: 'Nuovi annunci per "seiko"',
        content: 'Seiko Turtle SRP777 - 220 € - Milano',
      );
      expect(l, isNotNull);
      expect(l!.source, 'Subito');
      expect(l.price, 220);
    });
    test('app non seguite ignorate', () {
      expect(
        listingFromNotification(
            packageName: 'com.whatsapp', title: 'Mario', content: 'Seiko 100€'),
        isNull,
      );
    });
    test('messaggi di chat ignorati', () {
      expect(
        listingFromNotification(
            packageName: 'fr.vinted', title: 'Anna ti ha scritto', content: 'Ciao!'),
        isNull,
      );
    });
  });
}
