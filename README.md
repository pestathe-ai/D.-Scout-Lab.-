# D. Scout Lab

App Android che trova **affari sugli orologi usati** (Seiko, Citizen, Omega, Zenith, Rado).
Un'app Dom Studio.

## Come funziona
1. Salvi le ricerche (con notifiche) nelle app di annunci: Subito, Vinted, Wallapop, eBay, Catawiki.
2. D. Scout Lab legge quelle notifiche, riconosce marca e modello, stima il valore di mercato
   e calcola sconto, margine e un punteggio da 0 a 100.
3. Se è un affare ti avvisa. Puoi anche incollare a mano un annuncio nella scheda **Valuta**.

Non usa i tuoi account e non fa ricerche automatiche sui siti: nessun rischio di ban.

## Come stima il valore
- **Catalogo** di ~35 modelli con referenze e fascia di prezzo dell'usato (indicativa).
- **Storico**: ogni annuncio visto aggiunge un prezzo; dopo 5 prezzi la stima si corregge,
  dopo 15 diventa "affidabile" (i prezzi richiesti vengono scontati del 10%).
- **Condizioni**: non funzionante, da revisionare (+ costo revisione), revisionato, scatola e garanzia.
- **Segnali**: marca scritta male, venditore con fretta, annuncio vago, facilità di rivendita.
- **Scarta**: repliche, ricambi/accessori, prezzi troppo bassi per essere veri.

## Limiti (v0.1)
- Legge solo quello che c'è nel testo della notifica (niente foto, niente link).
- Le notifiche arrivate con l'app chiusa vengono lette solo se sono ancora nella tendina.
- I prezzi del catalogo sono indicativi e vanno verificati; per i pezzi costosi controlla
  sempre l'autenticità dal vivo.
- eBay tramite API ufficiale: prevista in una prossima versione.

## Sviluppo
Il codice Dart è in `lib/` (logica pura in `lib/core/`, testata in `test/`).
Le cartelle `android/` e `ios/` vengono generate in CI da `tool/setup_platforms.sh`.
