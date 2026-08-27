import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';

/// تنسيق العملة في التطبيق
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'ar_SA',
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  static final NumberFormat _compactFormatter = NumberFormat.compact(
    locale: 'ar_SA',
  );

  /// تنسيق المبلغ مع رمز العملة
  static String format(double amount) {
    return _formatter.format(amount);
  }

  /// تنسيق المبلغ بدون كسور إن كانت صحيحة
  static String formatClean(double amount) {
    if (amount == amount.roundToDouble()) {
      return '${amount.toStringAsFixed(0)} ${AppConstants.currencySymbol}';
    }
    return format(amount);
  }

  /// تنسيق مدمج للأرقام الكبيرة
  static String formatCompact(double amount) {
    return _compactFormatter.format(amount);
  }
}
