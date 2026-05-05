import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/transaction.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
final _dateFormat = DateFormat('dd MMM yyyy');

String _formatCurrency(int amountPaise) {
  return _currency.format(amountPaise / 100);
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return '-';
  }
  return _dateFormat.format(date);
}

String _csvValue(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

Future<void> shareTransactionsPdf({
  required String title,
  required List<DonationTransaction> transactions,
  required int totalDonations,
  required int totalFees,
  required int totalPaid,
}) async {
  final doc = pw.Document();
  final headers = ['Date', 'Status', 'Donation', 'Fee', 'Total', 'Payment ID'];

  final data = transactions.map((tx) {
    return [
      _formatDate(tx.timestamp),
      tx.status,
      _formatCurrency(tx.donationAmount),
      _formatCurrency(tx.platformFee),
      _formatCurrency(tx.totalPaid),
      tx.razorpayPaymentId ?? '-',
    ];
  }).toList();

  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text(title, style: pw.TextStyle(fontSize: 18)),
        pw.SizedBox(height: 12),
        pw.Text('Total donations: ${_formatCurrency(totalDonations)}'),
        pw.Text('Total fees: ${_formatCurrency(totalFees)}'),
        pw.Text('Total paid: ${_formatCurrency(totalPaid)}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(headers: headers, data: data),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: '$title.pdf');
}

Future<void> shareTransactionsCsv({
  required String title,
  required List<DonationTransaction> transactions,
}) async {
  final buffer = StringBuffer();
  buffer.writeln('Date,Status,Donation,Fee,Total,Payment ID,Order ID,User ID');

  for (final tx in transactions) {
    buffer.writeln(
      [
        _csvValue(_formatDate(tx.timestamp)),
        _csvValue(tx.status),
        _csvValue(_formatCurrency(tx.donationAmount)),
        _csvValue(_formatCurrency(tx.platformFee)),
        _csvValue(_formatCurrency(tx.totalPaid)),
        _csvValue(tx.razorpayPaymentId ?? ''),
        _csvValue(tx.razorpayOrderId ?? ''),
        _csvValue(tx.userId),
      ].join(','),
    );
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$title.csv');
  await file.writeAsString(buffer.toString());

  await Share.shareXFiles([XFile(file.path)], text: title);
}
