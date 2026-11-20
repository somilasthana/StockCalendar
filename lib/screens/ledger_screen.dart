import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/dates.dart';
import '../logic/ledger.dart';
import '../state/calendar_controller.dart';

const _green = Color(0xFF188038);
const _greenDark = Color(0xFF81C995);

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  String? _symbol;

  @override
  Widget build(BuildContext context) {
    final calendar = context.watch<CalendarController>();
    final symbols = ledgerSymbols(calendar.series);
    final selected = _symbol != null && symbols.contains(_symbol) ? _symbol : null;
    final rows = selected == null
        ? const <LedgerRow>[]
        : ledgerRows(calendar.series, selected, today: dateOnly(DateTime.now()));
    final scheme = Theme.of(context).colorScheme;
    final green = Theme.of(context).brightness == Brightness.dark ? _greenDark : _green;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Stock Ledger'),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Symbol',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  hint: const Text('Select a stock'),
                  items: [
                    for (final symbol in symbols)
                      DropdownMenuItem(value: symbol, child: Text(symbol)),
                  ],
                  onChanged: symbols.isEmpty
                      ? null
                      : (value) => setState(() => _symbol = value),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                if (symbols.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'No buys yet.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (selected != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                'Decision Text',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'No buy dates through today.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        return _TimelineTile(
                          dateLabel: ledgerDateLabel(rows[index].date),
                          text: rows[index].text,
                          color: green,
                          isFirst: index == 0,
                          isLast: index == rows.length - 1,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.dateLabel,
    required this.text,
    required this.color,
    required this.isFirst,
    required this.isLast,
  });

  final String dateLabel;
  final String text;
  final Color color;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 4,
                  color: isFirst ? Colors.transparent : color,
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : color,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
