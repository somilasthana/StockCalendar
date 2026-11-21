import 'package:flutter/material.dart';

import 'expert_scrip.dart';
import 'expert_video.dart';

const _strategies = [
  'Fixed Total Amount per Week',
  'Fixed Stock Invested Amount',
];

const _amounts = ['Rs 1000', 'Rs 2000', 'Rs 5000', 'Rs 10000', 'Rs 50000'];

class ExpertOpinionScreen extends StatefulWidget {
  const ExpertOpinionScreen({super.key});

  @override
  State<ExpertOpinionScreen> createState() => _ExpertOpinionScreenState();
}

class _ExpertOpinionScreenState extends State<ExpertOpinionScreen> {
  ExpertScrip? _scrip;
  List<bool> _included = const [];
  String? _strategy;
  String? _amount;
  bool _loading = true;
  bool _failed = false;
  OverlayEntry? _nameTip;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final scrip = await loadSampleScrip();
      if (!mounted) return;
      setState(() {
        _scrip = scrip;
        _included = List<bool>.filled(scrip.stocks.length, true);
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
          const _ChoiceField(
            label: "Expert's Scrip",
            value: 'Default Scrip',
            choices: ['Default Scrip'],
            enabled: false,
          ),
          const SizedBox(height: 16),
          ExpertVideo(url: scrip.youtubeUrl),
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
            choices: _amounts,
            onChanged: (value) => setState(() => _amount = value),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Add to Calendar'),
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
