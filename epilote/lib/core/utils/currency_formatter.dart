import 'package:intl/intl.dart';

/// Formatage monétaire XAF (FCFA)
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat('#,###', 'fr_FR');

  /// 150000 → "150 000 FCFA"
  static String format(num amount) {
    return '${_formatter.format(amount)} FCFA';
  }

  /// 150000 → "150 000"
  static String formatNoSymbol(num amount) {
    return _formatter.format(amount);
  }

  /// Compact : 1500000 → "1,5M FCFA"
  static String formatCompact(num amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M FCFA';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K FCFA';
    }
    return format(amount);
  }
}
