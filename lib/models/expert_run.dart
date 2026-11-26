import '../logic/dates.dart';

/// Saved with an expert simulation so the insight screen can name the scrip
/// and plot the amount chosen on Expert Opinion.
class ExpertRun {
  ExpertRun({
    required this.scripName,
    required this.strategy,
    required this.amount,
    required DateTime published,
  }) : published = dateOnly(published);

  /// Label selected in the Expert's Scrip dropdown.
  final String scripName;

  /// Allocation strategy selected with that scrip.
  final String strategy;

  /// Rupee amount selected in the Amount dropdown.
  final int amount;

  /// First day the simulation may buy.
  final DateTime published;

  String get signature =>
      '$scripName|$strategy|$amount|${formatIsoDate(published)}';

  Map<String, Object> toJson() => {
    'scripName': scripName,
    'strategy': strategy,
    'amount': amount,
    'published': formatIsoDate(published),
  };

  factory ExpertRun.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('The saved plan could not be read.');
    }
    final map = Map<String, dynamic>.from(raw);
    final name = (map['scripName'] as String?)?.trim() ?? '';
    final strategy = (map['strategy'] as String?)?.trim() ?? '';
    final amount = map['amount'];
    final published = map['published'];
    if (name.isEmpty || strategy.isEmpty) {
      throw const FormatException('The saved plan could not be read.');
    }
    if (amount is! int || amount < 1 || published is! String) {
      throw const FormatException('The saved plan could not be read.');
    }
    return ExpertRun(
      scripName: name,
      strategy: strategy,
      amount: amount,
      published: parseIsoDate(published),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExpertRun &&
      other.scripName == scripName &&
      other.strategy == strategy &&
      other.amount == amount &&
      other.published == published;

  @override
  int get hashCode => Object.hash(scripName, strategy, amount, published);
}

const defaultExpertScripName = 'Default Scrip';

const fixedStockInvestedAmount = 'Fixed Stock Invested Amount';

const expertAmountChoices = [1000, 2000, 5000, 10000, 50000];

const expertAmountLabels = [
  'Rs 1000',
  'Rs 2000',
  'Rs 5000',
  'Rs 10000',
  'Rs 50000',
];
