import 'package:flutter/material.dart';

import '../logic/dates.dart';
import '../logic/fixed_amount_plan.dart';
import '../models/buy_series.dart';
import '../models/daily_bar.dart';
import '../models/expert_run.dart';
import '../services/yahoo_price_service.dart';
import '../widgets/start_date_picker.dart';
import 'expert_scrip.dart';
import 'expert_simulation_store.dart';
import 'expert_video.dart';

const _strategies = ['Fixed Total Amount per Week', fixedStockInvestedAmount];

const expertPerformanceLabel = 'Add to Calendar and Check Performance';

typedef ApplyExpertBuys = Future<String?> Function(List<BuySeries> buys);

/// What Expert Opinion had selected when the buys were saved.
class ExpertOpinionCommit {
  const ExpertOpinionCommit({
    required this.summary,
    required this.index,
    required this.included,
    required this.strategy,
    required this.amount,
  });

  final String summary;
  final int index;
  final List<bool> included;
  final String? strategy;
  final String? amount;
}

typedef ExpertCommitted = void Function(ExpertOpinionCommit commit);

class ExpertOpinionScreen extends StatefulWidget {
  const ExpertOpinionScreen({
    super.key,
    this.onApply,
    this.onRun,
    this.onCommitted,
    this.prices,
    this.store,
    this.clock,
    this.scrips = const [],
    this.initialIndex = 0,
    this.initialIncluded = const [],
    this.initialStrategy,
    this.initialAmount,
  });

  /// Replaces the expert calendar after the simulation file is saved.
  final ApplyExpertBuys? onApply;

  /// Remembers the dropdown scrip, strategy, and amount for the insight screen.
  final void Function(ExpertRun run)? onRun;

  /// Saves the buys, then the host opens the insight screen.
  ///
  /// When this is set the screen does not pop itself.
  final ExpertCommitted? onCommitted;

  /// Closing prices for tests. Production loads them from Yahoo.
  final Future<Map<String, Map<String, double>>> Function(
    List<ExpertStock> basket,
    DateTime from,
    DateTime to,
  )?
  prices;

  final ExpertSimulationStore? store;

  /// Clock for the simulation end date. Tests pin this. Production uses now.
  final DateTime Function()? clock;

  /// Imported expert scrips. Empty means the sample and Default Scrip.
  final List<ExpertScrip> scrips;

  /// Restores the screen that was open when the buys were saved.
  final int initialIndex;
  final List<bool> initialIncluded;
  final String? initialStrategy;
  final String? initialAmount;

  @override
  State<ExpertOpinionScreen> createState() => _ExpertOpinionScreenState();
}

class _ExpertOpinionScreenState extends State<ExpertOpinionScreen> {
  ExpertScrip? _scrip;
  List<ExpertScrip> _imported = const [];
  List<String> _labels = const [];
  int _index = 0;
  List<bool> _included = const [];
  String? _strategy;
  String? _amount;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  OverlayEntry? _nameTip;

  String get _scripName =>
      _imported.isEmpty ? defaultExpertScripName : _labels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _strategy = widget.initialStrategy;
    _amount = widget.initialAmount;
    if (widget.scrips.isNotEmpty) {
      final last = widget.scrips.length - 1;
      final index = widget.initialIndex.clamp(0, last);
      _showImported(
        widget.scrips,
        index: index,
        included: widget.initialIncluded,
      );
      _loading = false;
    } else {
      _load();
    }
  }

  void _showImported(
    List<ExpertScrip> scrips, {
    int index = 0,
    List<bool>? included,
  }) {
    _imported = List<ExpertScrip>.unmodifiable(scrips);
    _labels = expertScripLabels(_imported);
    _index = index;
    _scrip = _imported[index];
    final count = _imported[index].stocks.length;
    _included = included != null && included.length == count
        ? List<bool>.from(included)
        : List<bool>.filled(count, true);
  }

  void _selectScrip(String? label) {
    if (label == null) return;
    final index = _labels.indexOf(label);
    if (index < 0 || index == _index) return;
    _hideName();
    setState(() => _showImported(_imported, index: index));
  }

  Future<void> _load() async {
    try {
      final scrip = await loadSampleScrip();
      if (!mounted) return;
      final restored = widget.initialIncluded;
      setState(() {
        _scrip = scrip;
        _included = restored.length == scrip.stocks.length
            ? List<bool>.from(restored)
            : List<bool>.filled(scrip.stocks.length, true);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _hideName();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = const TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w500,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            style: titleStyle,
            children: [
              const TextSpan(text: 'Expert '),
              TextSpan(
                text: 'Opinion',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed || _scrip == null
          ? const Center(child: Text('The sample could not be loaded.'))
          : _body(context, _scrip!),
    );
  }

  Widget _body(BuildContext context, ExpertScrip scrip) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceField(
            label: "Expert's Scrip",
            value: _scripName,
            choices: _imported.isEmpty
                ? const [defaultExpertScripName]
                : _labels,
            enabled: _imported.isNotEmpty,
            onChanged: _imported.isEmpty ? null : _selectScrip,
          ),
          const SizedBox(height: 16),
          ExpertVideo(
            key: ValueKey('$_index:${scrip.youtubeUrl}'),
            url: scrip.youtubeUrl,
          ),
          const SizedBox(height: 20),
          _line(theme, 'Name', scrip.authorName),
          _line(theme, 'Investment Firm', scrip.investmentFirm),
          _line(theme, 'Description', scrip.description),
          _line(
            theme,
            'Published Date',
            formatPublishedDate(scrip.publishedDate),
          ),
          const SizedBox(height: 8),
          Text(
            'Stock Pick Suggested',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          Divider(height: 16, thickness: 1, color: theme.dividerColor),
          for (var index = 0; index < scrip.stocks.length; index++)
            _stockRow(theme, scrip.stocks[index], index),
          const SizedBox(height: 12),
          _ChoiceField(
            label: 'Allocation Strategy',
            value: _strategy,
            choices: _strategies,
            onChanged: (value) => setState(() => _strategy = value),
          ),
          const SizedBox(height: 12),
          _ChoiceField(
            label: 'Amount',
            value: _amount,
            choices: expertAmountLabels,
            onChanged: (value) => setState(() => _amount = value),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _busy ? null : _addToCalendar,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        expertPerformanceLabel,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockRow(ThemeData theme, ExpertStock stock, int index) {
    final symbolStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    stock.code,
                    overflow: TextOverflow.ellipsis,
                    style: symbolStyle,
                  ),
                ),
                Builder(
                  builder: (anchor) => IconButton(
                    tooltip: 'Stock name',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    iconSize: 16,
                    onPressed: () => _showName(anchor, stock.name),
                    icon: const Icon(Icons.info_outline),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            height: 24,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                value: _included[index],
                onChanged: (value) => setState(() => _included[index] = value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showName(BuildContext anchor, String name) {
    _hideName();
    final overlay = Overlay.of(anchor);
    final entry = OverlayEntry(
      builder: (overlayContext) {
        final box = anchor.findRenderObject() as RenderBox?;
        final overlayBox = overlay.context.findRenderObject() as RenderBox?;
        if (box == null || !box.attached || overlayBox == null) {
          return const SizedBox.shrink();
        }
        final offset = box.localToGlobal(Offset.zero, ancestor: overlayBox);
        final screen = overlayBox.size;
        const popupWidth = 240.0;
        var left = offset.dx;
        if (left + popupWidth > screen.width - 8) {
          left = screen.width - 8 - popupWidth;
        }
        if (left < 8) left = 8;
        var top = offset.dy + box.size.height + 4;
        const popupHeight = 72.0;
        if (top + popupHeight > screen.height - 8) {
          top = offset.dy - popupHeight - 4;
        }
        if (top < 8) top = 8;
        final theme = Theme.of(overlayContext);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideName,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: popupWidth,
              child: Material(
                elevation: 6,
                color: theme.colorScheme.surface,
                surfaceTintColor: theme.colorScheme.surfaceTint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 2, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Close',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 28,
                          ),
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: _hideName,
                        ),
                      ),
                      Text(name, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    _nameTip = entry;
    overlay.insert(entry);
  }

  Future<void> _addToCalendar() async {
    final scrip = _scrip;
    if (scrip == null || _busy) return;
    final basket = <ExpertStock>[
      for (var index = 0; index < scrip.stocks.length; index++)
        if (_included[index]) scrip.stocks[index],
    ];
    if (basket.isEmpty) {
      await _warn('Nothing to add. No stock symbol is picked.');
      return;
    }
    final strategy = _strategy;
    final amountLabel = _amount;
    if (strategy == null || amountLabel == null) {
      await _warn('Choose an allocation strategy and an amount.');
      return;
    }
    if (strategy != fixedStockInvestedAmount) {
      await _warn(
        'Fixed Total Amount per Week does not add buys yet. '
        'The calendar is unchanged.',
      );
      return;
    }
    final amount = rupeeAmount(amountLabel);
    if (amount == null || amount < 1) {
      await _warn('The amount could not be read.');
      return;
    }
    final today = indiaDate((widget.clock ?? DateTime.now)().toUtc());
    final start = await showStartDatePicker(context, today: today);
    if (!mounted || start == null) return;
    if (!hasMarketDay(start, today)) {
      await _warn(
        describeFixedAmount(
          const FixedAmountPlan(status: FixedAmountStatus.noMarketDays),
          amount,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    var leaving = false;
    try {
      final closes = await (widget.prices ?? _downloadCloses)(
        basket,
        start,
        today,
      );
      if (!mounted) return;
      final plan = planFixedAmount(
        title: scrip.title,
        basket: [
          for (final stock in basket)
            PlanStock(name: stock.name, code: stock.code),
        ],
        amount: amount,
        published: start,
        today: today,
        closes: closes,
        createdAt: (widget.clock ?? DateTime.now)().toUtc(),
      );
      if (plan.status != FixedAmountStatus.ready) {
        await _warn(describeFixedAmount(plan, amount));
        return;
      }
      final apply = widget.onApply;
      if (apply == null) {
        await _warn('Could not save these buys.');
        return;
      }
      final run = ExpertRun(
        scripName: _scripName,
        strategy: strategy,
        amount: amount,
        published: start,
      );
      final saved = await (widget.store ?? ExpertSimulationStore()).write(
        plan.buys,
        run: run,
      );
      if (!mounted) return;
      if (saved != null) {
        await _warn(saved);
        return;
      }
      final replaced = await apply(plan.buys);
      if (replaced != null) {
        if (mounted) await _warn(replaced);
        return;
      }
      widget.onRun?.call(run);
      if (!mounted) return;
      leaving = true;
      final commit = ExpertOpinionCommit(
        summary: describeFixedAmount(plan, amount),
        index: _index,
        included: List<bool>.from(_included),
        strategy: strategy,
        amount: amountLabel,
      );
      final committed = widget.onCommitted;
      if (committed != null) {
        committed(commit);
        return;
      }
      Navigator.pop(context, commit.summary);
    } on PriceLookupException catch (error) {
      if (!mounted) return;
      await _warn('${error.message} Nothing was added.');
    } catch (_) {
      if (!mounted) return;
      await _warn('The price service did not respond. Nothing was added.');
    } finally {
      if (mounted && !leaving) setState(() => _busy = false);
    }
  }

  Future<Map<String, Map<String, double>>> _downloadCloses(
    List<ExpertStock> basket,
    DateTime from,
    DateTime to,
  ) async {
    final service = YahooPriceService();
    try {
      final closes = <String, Map<String, double>>{};
      for (final stock in basket) {
        final bars = await service.load(stock.code, from: from, to: to);
        closes[normalizeSymbol(stock.code)] = _closesByDate(bars);
      }
      return closes;
    } finally {
      service.close();
    }
  }

  Map<String, double> _closesByDate(List<DailyBar> bars) {
    final prices = <String, double>{};
    for (final bar in bars) {
      final close = bar.close;
      if (close == null || close <= 0) continue;
      prices[formatIsoDate(bar.date)] = close;
    }
    return prices;
  }

  Future<void> _warn(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _hideName() {
    final tip = _nameTip;
    _nameTip = null;
    if (tip != null && tip.mounted) tip.remove();
  }

  Widget _line(ThemeData theme, String label, String value) {
    final style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.value,
    required this.choices,
    this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final List<String> choices;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemStyle = theme.textTheme.labelLarge;
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$value'),
      initialValue: value,
      isExpanded: true,
      isDense: true,
      iconSize: 20,
      style: itemStyle,
      items: [
        for (final choice in choices)
          DropdownMenuItem(
            value: choice,
            child: Text(
              choice,
              overflow: TextOverflow.ellipsis,
              style: itemStyle,
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
