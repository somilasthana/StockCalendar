import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/dates.dart';
import '../models/buy_series.dart';
import 'until_picker.dart';

class RepeatDraft {
  RepeatDraft({
    this.frequency = RepeatFrequency.none,
    this.interval = 1,
    this.endType = RepeatEnd.forever,
    this.count = 10,
    this.untilDate,
  });

  RepeatFrequency frequency;
  int interval;
  RepeatEnd endType;
  int count;
  DateTime? untilDate;

  String get label {
    if (frequency == RepeatFrequency.none) return "Doesn't repeat";
    final sample = BuySeries(
      id: 'draft',
      stockName: 'Draft',
      symbol: 'DRAFT',
      notes: '',
      anchorDate: DateTime(2026, 9, 23),
      frequency: frequency,
      interval: interval < 1 ? 1 : interval,
      endType: endType,
      count: count,
      untilDate: untilDate,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    return repeatLabel(sample);
  }
}

Future<RepeatDraft?> showRepeatSheet(BuildContext context, RepeatDraft current, DateTime anchor) {
  return showModalBottomSheet<RepeatDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => RepeatSheet(initial: current, anchor: anchor),
  );
}

class RepeatSheet extends StatefulWidget {
  const RepeatSheet({super.key, required this.initial, required this.anchor});

  final RepeatDraft initial;
  final DateTime anchor;

  @override
  State<RepeatSheet> createState() => _RepeatSheetState();
}

class _RepeatSheetState extends State<RepeatSheet> {
  late RepeatDraft _draft;
  late final TextEditingController _interval;
  late final TextEditingController _count;
  String? _error;

  @override
  void initState() {
    super.initState();
    _draft = RepeatDraft(
      frequency: widget.initial.frequency,
      interval: widget.initial.interval,
      endType: widget.initial.endType,
      count: widget.initial.count,
      untilDate: widget.initial.untilDate,
    );
    _interval = TextEditingController(text: '${_draft.interval}');
    _count = TextEditingController(text: '${_draft.count}');
  }

  @override
  void dispose() {
    _interval.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _pickUntil() async {
    final picked = await showUntilPicker(
      context,
      anchor: widget.anchor,
      selected: _draft.untilDate,
    );
    if (!mounted) return;
    setState(() {
      if (picked == null) {
        if (_draft.untilDate == null) _draft.endType = RepeatEnd.forever;
      } else {
        _draft.endType = RepeatEnd.until;
        _draft.untilDate = picked;
      }
    });
  }

  void _done() {
    final interval = int.tryParse(_interval.text.trim()) ?? 0;
    final count = int.tryParse(_count.text.trim()) ?? 0;
    if (_draft.frequency == RepeatFrequency.days && interval < 1) {
      setState(() => _error = 'Enter how many days between buys.');
      return;
    }
    if (_draft.frequency != RepeatFrequency.none &&
        _draft.endType == RepeatEnd.count &&
        count < 1) {
      setState(() => _error = 'Enter how many times to repeat.');
      return;
    }
    if (_draft.frequency != RepeatFrequency.none &&
        _draft.endType == RepeatEnd.until &&
        _draft.untilDate == null) {
      setState(() => _error = 'Choose the last date.');
      return;
    }
    _draft.interval = interval < 1 ? 1 : interval;
    _draft.count = count < 1 ? 1 : count;
    Navigator.pop(context, _draft);
  }

  @override
  Widget build(BuildContext context) {
    final repeating = _draft.frequency != RepeatFrequency.none;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor = dark ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92 - bottom,
        ),
        child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: textColor,
            displayColor: textColor,
          ),
          listTileTheme: ListTileThemeData(textColor: textColor),
        ),
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Repeat',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: textColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _done,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              repeating
                  ? 'This buy repeats on weekdays. Saturday and Sunday are skipped and are not counted.'
                  : "This buy does not repeat.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _card(
              children: [
                RadioGroup<RepeatFrequency>(
                  groupValue: _draft.frequency,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _draft.frequency = value;
                      if (value == RepeatFrequency.days && _interval.text.trim().isEmpty) {
                        _interval.text = '1';
                      }
                    });
                  },
                  child: Column(
                    children: [
                      _radio(RepeatFrequency.none, "Don't repeat"),
                      if (_draft.frequency == RepeatFrequency.days)
                        _everyDays()
                      else
                        _radio(RepeatFrequency.days, 'Every day'),
                      _radio(RepeatFrequency.weeks, 'Every week'),
                      _radio(RepeatFrequency.months, 'Every month'),
                      _radio(RepeatFrequency.years, 'Every year'),
                    ],
                  ),
                ),
              ],
            ),
            if (repeating) ...[
              const SizedBox(height: 16),
              Text('Duration', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _card(
                children: [
                  RadioGroup<RepeatEnd>(
                    groupValue: _draft.endType,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _draft.endType = value);
                      if (value == RepeatEnd.until) _pickUntil();
                    },
                    child: Column(
                      children: [
                        const RadioListTile<RepeatEnd>(
                          value: RepeatEnd.forever,
                          title: Text('Forever'),
                        ),
                        RadioListTile<RepeatEnd>(
                          value: RepeatEnd.count,
                          title: _timesField(),
                        ),
                        RadioListTile<RepeatEnd>(
                          value: RepeatEnd.until,
                          title: Text(
                            _draft.untilDate == null
                                ? 'Until'
                                : 'Until ${prettyDate(_draft.untilDate!)}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
        ),
        ),
      ),
    );
  }

  Widget _everyDays() {
    return RadioListTile<RepeatFrequency>(
      value: RepeatFrequency.days,
      title: Row(
        children: [
          const Text('Every'),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          const Text('day'),
        ],
      ),
    );
  }

  Widget _timesField() {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: TextField(
            controller: _count,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        const Text('times total'),
      ],
    );
  }

  Widget _radio(RepeatFrequency frequency, String label) {
    return RadioListTile<RepeatFrequency>(
      value: frequency,
      title: Text(label),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
