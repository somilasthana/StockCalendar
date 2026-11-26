import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/dates.dart';
import '../models/buy_series.dart';
import '../state/calendar_controller.dart';
import 'repeat_sheet.dart';

const manualBuyDisabled = 'Add or Edit of Buy Event is disabled';

Future<void> showBuySheet(
  BuildContext context, {
  required DateTime day,
  BuySeries? existing,
}) {
  final calendar = context.read<CalendarController>();
  if (calendar.manualBuysLocked && existing == null) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(manualBuyDisabled),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => ChangeNotifierProvider<CalendarController>.value(
      value: calendar,
      child: BuySheet(
        day: dateOnly(day),
        existing: existing,
        readOnly: calendar.manualBuysLocked,
      ),
    ),
  );
}

class BuySheet extends StatefulWidget {
  const BuySheet({
    super.key,
    required this.day,
    this.existing,
    this.readOnly = false,
  });

  final DateTime day;
  final BuySeries? existing;
  final bool readOnly;

  @override
  State<BuySheet> createState() => _BuySheetState();
}

class _BuySheetState extends State<BuySheet> {
  late final TextEditingController _name;
  late final TextEditingController _symbol;
  late final TextEditingController _notes;
  late RepeatDraft _repeat;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.stockName ?? '');
    _symbol = TextEditingController(text: existing?.symbol ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _repeat = RepeatDraft(
      frequency: existing?.frequency ?? RepeatFrequency.none,
      interval: existing?.interval ?? 1,
      endType: existing?.endType ?? RepeatEnd.forever,
      count: existing?.count ?? 10,
      untilDate: existing?.untilDate,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _editRepeat() async {
    final next = await showRepeatSheet(context, _repeat, widget.day);
    if (next != null) setState(() => _repeat = next);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final calendar = context.read<CalendarController>();
    final existing = widget.existing;
    final String? error;
    if (existing == null) {
      error = await calendar.createBuy(
        stockName: _name.text,
        symbol: _symbol.text,
        notes: _notes.text,
        day: widget.day,
        frequency: _repeat.frequency,
        interval: _repeat.interval,
        endType: _repeat.endType,
        count: _repeat.count,
        untilDate: _repeat.untilDate,
      );
    } else {
      error = await calendar.updateBuy(
        series: existing,
        day: widget.day,
        stockName: _name.text,
        symbol: _symbol.text,
        notes: _notes.text,
      );
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this buy?'),
        content: const Text(
          'This day and every later day in the series will be removed. Earlier days stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<CalendarController>().deleteBuy(existing, widget.day);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final locked = widget.readOnly;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = (MediaQuery.sizeOf(context).height - bottom) * 0.72;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        locked
                            ? 'Buy'
                            : editing
                            ? 'Edit buy'
                            : 'Stock to buy',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _name,
                        readOnly: locked,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Stock to buy',
                          prefixIcon: Icon(Icons.show_chart),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _symbol,
                        readOnly: locked,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Stock symbol',
                          hintText: 'ITC',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: Text(prettyDate(widget.day)),
                      ),
                      TextField(
                        controller: _notes,
                        readOnly: locked,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.repeat),
                        title: Text(
                          editing
                              ? repeatLabel(widget.existing!)
                              : _repeat.label,
                        ),
                        subtitle: editing
                            ? const Text('Repeat stays as it was saved')
                            : null,
                        trailing: editing || locked
                            ? null
                            : const Icon(Icons.chevron_right),
                        onTap: editing || locked ? null : _editRepeat,
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    if (editing && !locked)
                      TextButton(
                        onPressed: _saving ? null : _delete,
                        child: const Text('Remove'),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving || locked ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
