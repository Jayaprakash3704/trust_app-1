import 'package:intl/intl.dart';

final _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

String formatInr(int amountPaise) {
  final value = amountPaise / 100;
  return _inrFormat.format(value);
}
