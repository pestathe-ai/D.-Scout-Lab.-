import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/catalog.dart';
import '../core/models.dart';
import '../core/valuator.dart';
import 'theme.dart';

class ValuationCard extends StatefulWidget {
  final Listing? listing;
  final Valuation valuation;
  final VoidCallback? onDismiss;
  final bool initiallyExpanded;

  const ValuationCard({
    super.key,
    required this.valuation,
    this.listing,
    this.onDismiss,
    this.initiallyExpanded = false,
  });

  @override
  State<ValuationCard> createState() => _ValuationCardState();
}

class _ValuationCardState extends State<ValuationCard> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final v = widget.valuation;
    final l = widget.listing;
    final color = verdictColor(v.verdict);
    final name = v.model?.name ?? v.brand?.name ?? (l?.title ?? 'Annuncio');
    final t = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Pill(text: verdictLabel(v.verdict), color: color),
                  const SizedBox(width: 8),
                  if (l != null)
                    Flexible(
                      child: Text(
                        '${l.source} · ${_ago(l.seenAt)}',
                        style: t.bodySmall?.copyWith(color: Colors.grey.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const Spacer(),
                  if (v.score > 0) _Score(score: v.score, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(name,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(euro(v.price),
                      style: t.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800, color: Brandbook.inchiostro)),
                  const SizedBox(width: 12),
                  if (v.valueLow != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'vale ${euro(v.valueLow)} – ${euro(v.valueHigh)}',
                          style: t.bodyMedium?.copyWith(color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
              if (v.margin != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Fact(
                      label: 'Margine',
                      value: euro(v.margin),
                      color: v.margin! > 0 ? Brandbook.verde : Brandbook.rosso,
                    ),
                    if (v.discount != null)
                      _Fact(
                        label: 'Sconto',
                        value: '${(v.discount! * 100).round()}%',
                        color: v.discount! > 0 ? Brandbook.verde : Colors.grey.shade700,
                      ),
                    _Fact(
                        label: 'Fiducia',
                        value: confidenceLabel(v.confidence),
                        color: Brandbook.blu),
                    if (v.liquidity != null)
                      _Fact(
                          label: 'Rivendita',
                          value: _liq(v.liquidity!),
                          color: Brandbook.blu),
                  ],
                ),
              ],
              if (_open) ...[
                const SizedBox(height: 12),
                for (final r in v.reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(r, style: t.bodyMedium)),
                      ],
                    ),
                  ),
                if (l != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Brandbook.carta,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${l.title}\n${l.text}'.trim(), style: t.bodySmall),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: '${l.title} ${l.text}'.trim()));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Copiato: cercalo nell\'app di annunci')));
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copia'),
                      ),
                      const Spacer(),
                      if (widget.onDismiss != null)
                        TextButton.icon(
                          onPressed: widget.onDismiss,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Nascondi'),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _liq(Liquidity l) => switch (l) {
        Liquidity.alta => 'facile',
        Liquidity.media => 'media',
        Liquidity.bassa => 'lenta',
      };

  static String _ago(DateTime d) {
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'ora';
    if (m < 60) return '$m min fa';
    final h = m ~/ 60;
    if (h < 24) return '$h h fa';
    return '${h ~/ 24} g fa';
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

class _Score extends StatelessWidget {
  final int score;
  final Color color;
  const _Score({required this.score, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Text('$score',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      );
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Fact({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: '$label ',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          TextSpan(
              text: value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ])),
      );
}
