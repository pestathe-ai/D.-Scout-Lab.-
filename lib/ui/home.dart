import 'package:flutter/material.dart';

import '../core/catalog.dart';
import '../core/models.dart';
import '../core/sources.dart';
import '../core/text_utils.dart';
import '../core/valuator.dart';
import '../services/alerts.dart';
import '../services/scout.dart';
import 'theme.dart';
import 'valuation_card.dart';

class HomePage extends StatefulWidget {
  final Scout scout;
  const HomePage({super.key, required this.scout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;

  Scout get scout => widget.scout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scout.start();
    if (scout.alertsOn) Alerts.requestPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al ritorno dalle impostazioni o dallo sfondo, rilegge le notifiche.
    if (state == AppLifecycleState.resumed) scout.start();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DealsPage(scout: scout, onOpenSettings: () => setState(() => _tab = 3)),
      _AllPage(scout: scout),
      _EvaluatePage(scout: scout),
      _SettingsPage(scout: scout),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('D. Scout Lab')),
      body: ListenableBuilder(
        listenable: scout,
        builder: (context, _) => pages[_tab],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: 'Affari'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Tutti'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Valuta'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Impostazioni'),
        ],
      ),
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Center(
          child: Text("un'app Dom Studio",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
      );
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  const _Hint(
      {required this.icon,
      required this.title,
      required this.body,
      this.action,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Brandbook.arancio),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            Text(body, style: t.bodyMedium),
            if (action != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------- Affari ----------------

class _DealsPage extends StatelessWidget {
  final Scout scout;
  final VoidCallback onOpenSettings;
  const _DealsPage({required this.scout, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final deals = scout.deals;
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        if (!scout.listenerGranted)
          _Hint(
            icon: Icons.notifications_active_outlined,
            title: 'Attiva la lettura delle notifiche',
            body:
                "D. Scout Lab legge le notifiche delle ricerche salvate di Subito, Vinted, Wallapop, Catawiki ed eBay e valuta ogni annuncio. Non usa il tuo account e non scrive a nessuno.",
            action: 'Attiva',
            onAction: scout.requestListenerPermission,
          ),
        if (deals.isEmpty)
          _Hint(
            icon: Icons.search,
            title: 'Nessun affare per ora',
            body:
                "Appena arriva una notifica con un prezzo sotto mercato la trovi qui. Se non l'hai ancora fatto, salva le ricerche nelle app di annunci (Impostazioni → Come iniziare). Puoi anche incollare un annuncio nella scheda Valuta.",
            action: 'Come iniziare',
            onAction: onOpenSettings,
          ),
        for (final e in deals)
          ValuationCard(
            key: ValueKey(e.listing.id),
            listing: e.listing,
            valuation: e.valuation,
            onDismiss: () => scout.dismiss(e.listing),
          ),
        const _Signature(),
      ],
    );
  }
}

// ---------------- Tutti ----------------

class _AllPage extends StatelessWidget {
  final Scout scout;
  const _AllPage({required this.scout});

  @override
  Widget build(BuildContext context) {
    final all = scout.entries;
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '${all.length} annunci visti · ${scout.historySize} prezzi nello storico',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        if (all.isEmpty)
          const _Hint(
            icon: Icons.inbox_outlined,
            title: 'Ancora vuoto',
            body:
                'Qui compaiono tutti gli annunci delle marche che segui, anche quelli a prezzo normale: servono a costruire lo storico dei prezzi.',
          ),
        for (final e in all)
          ValuationCard(
            key: ValueKey(e.listing.id),
            listing: e.listing,
            valuation: e.valuation,
            onDismiss: () => scout.dismiss(e.listing),
          ),
        const _Signature(),
      ],
    );
  }
}

// ---------------- Valuta ----------------

class _EvaluatePage extends StatefulWidget {
  final Scout scout;
  const _EvaluatePage({required this.scout});

  @override
  State<_EvaluatePage> createState() => _EvaluatePageState();
}

class _EvaluatePageState extends State<_EvaluatePage> {
  final _text = TextEditingController();
  final _price = TextEditingController();
  Valuation? _result;

  @override
  void dispose() {
    _text.dispose();
    _price.dispose();
    super.dispose();
  }

  double? get _priceValue {
    final p = _price.text.trim();
    if (p.isEmpty) return parsePrice(_text.text);
    return parsePrice('$p €');
  }

  void _evaluate() {
    FocusScope.of(context).unfocus();
    setState(() {
      _result = widget.scout.valuator.evaluateText(_text.text, _priceValue);
    });
  }

  Future<void> _save() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final l = Listing(
      id: listingIdFor('Manuale', text),
      source: 'Manuale',
      title: text.split('\n').first,
      text: text,
      price: _priceValue,
      seenAt: DateTime.now(),
    );
    await widget.scout.ingest(l, alert: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvato: conta anche per lo storico prezzi')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Incolla un annuncio',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          'Copia titolo e descrizione da Subito, Vinted o altri siti: ti dico quanto vale e se conviene.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: 'Es. Seiko SKX007 automatico, revisionato, 220 €',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Prezzo (se non è nel testo)',
            suffixText: '€',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: FilledButton(onPressed: _evaluate, child: const Text('Valuta'))),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: _save, child: const Text('Salva')),
        ]),
        if (_result != null) ...[
          const SizedBox(height: 12),
          ValuationCard(valuation: _result!, initiallyExpanded: true),
        ],
        const _Signature(),
      ],
    );
  }
}

// ---------------- Impostazioni ----------------

class _SettingsPage extends StatelessWidget {
  final Scout scout;
  const _SettingsPage({required this.scout});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final threshold = scout.settings.dealThreshold;
    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: Icon(
                scout.listenerGranted ? Icons.check_circle : Icons.error_outline,
                color: scout.listenerGranted ? Brandbook.verde : Brandbook.arancio,
              ),
              title: const Text('Lettura notifiche'),
              subtitle: Text(scout.listenerGranted
                  ? 'Attiva'
                  : 'Non attiva: senza questa l\'app non vede gli annunci'),
              trailing: scout.listenerGranted
                  ? null
                  : TextButton(
                      onPressed: scout.requestListenerPermission,
                      child: const Text('Attiva')),
            ),
            SwitchListTile(
              value: scout.alertsOn,
              onChanged: scout.setAlertsOn,
              title: const Text('Avvisami per gli affari'),
              subtitle: const Text('Una notifica quando trova un affare'),
            ),
          ]),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quando è un affare?',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    'Prezzo almeno del ${(threshold * 100).round()}% sotto il valore stimato, con margine positivo dopo spedizione e commissioni.'),
                Slider(
                  value: threshold,
                  min: 0.10,
                  max: 0.50,
                  divisions: 8,
                  label: '${(threshold * 100).round()}%',
                  onChanged: scout.setThreshold,
                ),
              ],
            ),
          ),
        ),
        Card(
          child: ExpansionTile(
            shape: const Border(),
            title: const Text('Come iniziare'),
            subtitle: const Text('Salva le ricerche nelle app di annunci'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                  '1. Tocca "Attiva" qui sopra e consenti a D. Scout Lab l\'accesso alle notifiche. Su Android 13 o più recenti, se è grigio: Impostazioni → App → D. Scout Lab → ⋮ → "Consenti impostazioni con limitazioni", poi riprova.\n\n'
                  '2. In ogni app di annunci cerca una marca (es. "Omega"), filtra per categoria Orologi e salva la ricerca con le notifiche attive:\n'
                  '   • Subito: "Salva ricerca" → notifiche attive\n'
                  '   • Vinted: "Salva ricerca" (icona campanella)\n'
                  '   • Wallapop: "Salva ricerca" → avvisi\n'
                  '   • eBay: "Salva questa ricerca" → notifiche push\n'
                  '   • Catawiki: segui la categoria o l\'oggetto\n\n'
                  '3. Fallo per ogni marca: Seiko, Citizen, Omega, Zenith, Rado. Aggiungi anche gli errori di battitura (es. "Omgea", "Zenit"): lì si trovano i prezzi migliori.\n\n'
                  '4. Lascia D. Scout Lab aperta in sottofondo (non chiuderla dalle app recenti). Quando la riapri, legge comunque le notifiche ancora presenti nella tendina.'),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            shape: const Border(),
            title: const Text('Catalogo modelli'),
            subtitle: Text('${models.length} modelli · ${brands.length} marche'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              for (final b in brands) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(b.name,
                        style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
                for (final m in models.where((m) => m.brandId == b.id))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(children: [
                      Expanded(child: Text(m.name, style: t.bodySmall)),
                      Text('${euro(m.low)} – ${euro(m.high)}', style: t.bodySmall),
                    ]),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                'Prezzi iniziali indicativi dell\'usato. Con lo storico raccolto la stima si corregge da sola.',
                style: t.bodySmall?.copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            shape: const Border(),
            title: const Text('App di annunci lette'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(sources.map((s) => s.name).join(' · '))],
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Svuota la lista annunci'),
            subtitle: const Text('Lo storico prezzi resta'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Svuotare la lista?'),
                  content: const Text('Gli annunci spariscono, lo storico dei prezzi resta.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Annulla')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Svuota')),
                  ],
                ),
              );
              if (ok == true) await scout.clearAll();
            },
          ),
        ),
        const _Signature(),
      ],
    );
  }
}
