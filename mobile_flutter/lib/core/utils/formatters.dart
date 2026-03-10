import 'package:intl/intl.dart';

/// Currency formatting utilities for Indian Rupee amounts.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _compactFormatter = NumberFormat.compact(locale: 'en_IN');

  static final _fullFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _fullWithDecimalsFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Formats an amount as ₹1,25,000 (Indian numeral system, no decimals).
  static String format(num amount) => _fullFormatter.format(amount);

  /// Formats an amount as ₹1,25,000.50 (with 2 decimal places).
  static String formatWithDecimals(num amount) =>
      _fullWithDecimalsFormatter.format(amount);

  /// Formats an amount compactly: ₹1.2L, ₹3.5K.
  static String formatCompact(num amount) =>
      '₹${_compactFormatter.format(amount)}';
}

/// Date formatting utilities.
class DateFormatter {
  DateFormatter._();

  static final _dateFormatter     = DateFormat('d MMM yyyy');
  static final _shortDateFormatter = DateFormat('d MMM');
  static final _dateTimeFormatter = DateFormat('d MMM yyyy, h:mm a');
  static final _timeFormatter     = DateFormat('h:mm a');

  /// e.g. "9 Mar 2026"
  static String date(DateTime dt) => _dateFormatter.format(dt);

  /// e.g. "9 Mar"
  static String shortDate(DateTime dt) => _shortDateFormatter.format(dt);

  /// e.g. "9 Mar 2026, 3:45 PM"
  static String dateTime(DateTime dt) => _dateTimeFormatter.format(dt);

  /// e.g. "3:45 PM"
  static String time(DateTime dt) => _timeFormatter.format(dt);

  /// Returns "2 hours ago", "just now", "Yesterday", etc.
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)    return '${diff.inHours}h ago';
    if (diff.inDays == 1)     return 'Yesterday';
    if (diff.inDays < 7)      return '${diff.inDays}d ago';
    return date(dt);
  }
}
