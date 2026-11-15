/// Short label for an axis or a column, such as ₹7 or ₹1.2L.
String shortRupee(double value) {
  final negative = value < 0;
  final abs = value.abs();
  final String body;
  if (abs >= 10000000) {
    body = '${_trim(abs / 10000000)}Cr';
  } else if (abs >= 100000) {
    body = '${_trim(abs / 100000)}L';
  } else if (abs >= 10000) {
    body = '${_trim(abs / 1000)}k';
  } else {
    body = _trim(abs);
  }
  return '${negative ? '-' : ''}₹$body';
}

/// Full rupee amount with Indian grouping, such as ₹1,23,456.50.
String fullRupee(double value) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(2);
  final bits = fixed.split('.');
  return '${negative ? '-' : ''}₹${_indianGroup(bits[0])}.${bits[1]}';
}

String signedPercent(double? value) {
  if (value == null) return '';
  final sign = value > 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)}%';
}

String _trim(double value) {
  final text = value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  if (!text.contains('.')) return text;
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _indianGroup(String digits) {
  if (digits.length <= 3) return digits;
  final parts = <String>[];
  var index = digits.length;
  parts.add(digits.substring(index - 3, index));
  index -= 3;
  while (index > 0) {
    final start = index - 2 < 0 ? 0 : index - 2;
    parts.insert(0, digits.substring(start, index));
    index = start;
  }
  return parts.join(',');
}

/// A ceiling that lands on 1, 2, 5, or 10 times a power of ten.
double niceMax(double peak) {
  if (peak <= 0) return 4;
  final padded = peak * 1.25;
  final exponent = _pow10((padded).floor().toString().length - 1);
  final fraction = padded / exponent;
  final nice = fraction <= 1
      ? 1
      : fraction <= 2
          ? 2
          : fraction <= 5
              ? 5
              : 10;
  final ceiling = nice * exponent;
  return ceiling < padded ? ceiling * 2 : ceiling;
}

double _pow10(int places) {
  var value = 1.0;
  for (var i = 0; i < places; i++) {
    value *= 10;
  }
  return value;
}
