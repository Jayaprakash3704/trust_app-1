import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DonationReceiptData {
  const DonationReceiptData({
    required this.donorName,
    required this.donationAmount,
    required this.platformFee,
    required this.totalPaid,
    required this.status,
    this.timestamp,
    this.transactionId,
  });

  final String donorName;
  final int donationAmount;
  final int platformFee;
  final int totalPaid;
  final String status;
  final DateTime? timestamp;
  final String? transactionId;
}

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
final _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

String _formatCurrency(int amountPaise) {
  return _currency.format(amountPaise / 100);
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '-';
  }
  return _dateTimeFormat.format(dateTime);
}

pw.PageTheme _buildWatermarkedTheme(pw.MemoryImage logoImage) {
  return pw.PageTheme(
    margin: const pw.EdgeInsets.all(24),
    buildBackground: (context) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Opacity(
          opacity: 0.08,
          child: pw.Image(logoImage, width: 300, height: 300),
        ),
      ),
    ),
  );
}

Future<Uint8List> buildDonationReceiptPdf(DonationReceiptData data) async {
  final doc = pw.Document();
  final logoBytes = await rootBundle.load('assets/images/app_logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final pageTheme = _buildWatermarkedTheme(logoImage);

  final rows = <List<String>>[
    ['Name', data.donorName],
    ['Status', data.status],
    ['Date', _formatDateTime(data.timestamp)],
    ['Donation', _formatCurrency(data.donationAmount)],
    ['Platform fee', _formatCurrency(data.platformFee)],
    ['Total paid', _formatCurrency(data.totalPaid)],
  ];

  if (data.transactionId != null && data.transactionId!.isNotEmpty) {
    rows.add(['Transaction ID', data.transactionId!]);
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pageTheme,
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logoImage, width: 28, height: 28),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(
                'Donation receipt',
                style: pw.TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Field', 'Value'],
          data: rows,
          cellAlignment: pw.Alignment.centerLeft,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Generated: ${_formatDateTime(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ),
  );

  return doc.save();
}

Future<void> shareDonationReceiptPdf(DonationReceiptData data) async {
  final bytes = await buildDonationReceiptPdf(data);
  await Printing.sharePdf(bytes: bytes, filename: 'donation_receipt.pdf');
}

Future<void> printDonationReceiptPdf(DonationReceiptData data) async {
  final bytes = await buildDonationReceiptPdf(data);
  await Printing.layoutPdf(onLayout: (_) async => bytes);
}
