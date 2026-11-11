import 'package:intl/intl.dart';

/// Helper utility terpusat untuk pemformatan angka, mata uang, dan teks.
class FormatHelper {
  FormatHelper._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Format angka menjadi format Rupiah lengkap (contoh: Rp 1.500.000).
  static String currency(num val) => _currencyFormat.format(val);

  /// Format angka ringkas dengan singkatan umum Indonesia (contoh: 1.5M, 250jt, 15rb).
  static String shortNum(num val) {
    final double numVal = val.toDouble();
    final double absVal = numVal.abs();
    final String sign = numVal < 0 ? '-' : '';

    if (absVal >= 1000000000000) {
      return '$sign${(absVal / 1000000000000).toStringAsFixed(1)}T';
    }
    if (absVal >= 1000000000) {
      return '$sign${(absVal / 1000000000).toStringAsFixed(1)}M';
    }
    if (absVal >= 1000000) {
      return '$sign${(absVal / 1000000).toStringAsFixed(1)}jt';
    }
    if (absVal >= 1000) {
      return '$sign${(absVal / 1000).toStringAsFixed(0)}rb';
    }
    return '$sign${absVal.toStringAsFixed(0)}';
  }
}
