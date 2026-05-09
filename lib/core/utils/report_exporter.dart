import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expense.dart';
import '../models/transaction.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ');
final _dateFormat = DateFormat('dd MMM yyyy');
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

String _csvValue(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _resolveUserName(Map<String, String> userNames, String userId) {
  final name = userNames[userId]?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  return userId.isNotEmpty ? userId : '-';
}

List<MapEntry<String, int>> _sortedExpenseCategoryTotals(
  List<Expense> expenses,
) {
  final totals = <String, int>{};
  for (final expense in expenses) {
    final rawCategory = expense.category.trim();
    final category = rawCategory.isEmpty ? 'Uncategorized' : rawCategory;
    totals[category] = (totals[category] ?? 0) + expense.amount;
  }

  final entries = totals.entries.toList()
    ..sort((a, b) {
      final byValue = b.value.compareTo(a.value);
      if (byValue != 0) {
        return byValue;
      }
      return a.key.compareTo(b.key);
    });
  return entries;
}

pw.PageTheme _buildWatermarkedTheme(pw.MemoryImage logoImage) {
  return pw.PageTheme(
    margin: const pw.EdgeInsets.all(24),
    buildBackground: (context) => pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Opacity(
          opacity: 0.08,
          child: pw.Image(logoImage, width: 360, height: 360),
        ),
      ),
    ),
  );
}

Future<void> shareTransactionsPdf({
  required String title,
  required List<DonationTransaction> transactions,
  required int totalDonations,
  required int totalFees,
  required int totalPaid,
  required Map<String, String> userNames,
  String? rangeLabel,
  DateTime? generatedAt,
}) async {
  final doc = pw.Document();
  final logoBytes = await rootBundle.load('assets/images/app_logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final headers = ['Date', 'Name', 'Status', 'Donation', 'Fee', 'Total'];
  final pageTheme = _buildWatermarkedTheme(logoImage);

  final data = transactions.map((tx) {
    return [
      _formatDateTime(tx.timestamp),
      _resolveUserName(userNames, tx.userId),
      tx.status,
      _formatCurrency(tx.donationAmount),
      _formatCurrency(tx.platformFee),
      _formatCurrency(tx.totalPaid),
    ];
  }).toList();

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
              child: pw.Text(title, style: pw.TextStyle(fontSize: 18)),
            ),
          ],
        ),
        if (rangeLabel != null)
          pw.Text('Range: $rangeLabel', style: const pw.TextStyle()),
        if (generatedAt != null)
          pw.Text(
            'Generated: ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(),
          ),
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
  required Map<String, String> userNames,
  String? rangeLabel,
  DateTime? generatedAt,
}) async {
  final buffer = StringBuffer();
  if (rangeLabel != null) {
    buffer.writeln('Report Range,${_csvValue(rangeLabel)}');
  }
  if (generatedAt != null) {
    buffer.writeln('Generated At,${_csvValue(_formatDateTime(generatedAt))}');
  }
  if (rangeLabel != null || generatedAt != null) {
    buffer.writeln('');
  }
  buffer.writeln('Date,Name,Status,Donation,Fee,Total');

  for (final tx in transactions) {
    buffer.writeln(
      [
        _csvValue(_formatDateTime(tx.timestamp)),
        _csvValue(_resolveUserName(userNames, tx.userId)),
        _csvValue(tx.status),
        _csvValue(_formatCurrency(tx.donationAmount)),
        _csvValue(_formatCurrency(tx.platformFee)),
        _csvValue(_formatCurrency(tx.totalPaid)),
      ].join(','),
    );
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$title.csv');
  await file.writeAsString(buffer.toString());

  await Share.shareXFiles([XFile(file.path)], text: title);
}

Future<void> shareDonationsPdf({
  required String title,
  required List<DonationTransaction> transactions,
  required int totalDonations,
  required Map<String, String> userNames,
  String? rangeLabel,
  DateTime? generatedAt,
}) async {
  final doc = pw.Document();
  final logoBytes = await rootBundle.load('assets/images/app_logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final headers = ['Date', 'Name', 'Status', 'Donation'];
  final pageTheme = _buildWatermarkedTheme(logoImage);

  final data = transactions.map((tx) {
    return [
      _formatDateTime(tx.timestamp),
      _resolveUserName(userNames, tx.userId),
      tx.status,
      _formatCurrency(tx.donationAmount),
    ];
  }).toList();

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
              child: pw.Text(title, style: pw.TextStyle(fontSize: 18)),
            ),
          ],
        ),
        if (rangeLabel != null)
          pw.Text('Range: $rangeLabel', style: const pw.TextStyle()),
        if (generatedAt != null)
          pw.Text(
            'Generated: ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(),
          ),
        pw.SizedBox(height: 12),
        pw.Text('Total donations: ${_formatCurrency(totalDonations)}'),
        pw.Text('Transactions: ${transactions.length}'),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(headers: headers, data: data),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: '$title.pdf');
}

Future<void> shareDonationsCsv({
  required String title,
  required List<DonationTransaction> transactions,
  required Map<String, String> userNames,
  String? rangeLabel,
  DateTime? generatedAt,
}) async {
  final buffer = StringBuffer();
  if (rangeLabel != null) {
    buffer.writeln('Report Range,${_csvValue(rangeLabel)}');
  }
  if (generatedAt != null) {
    buffer.writeln('Generated At,${_csvValue(_formatDateTime(generatedAt))}');
  }
  if (rangeLabel != null || generatedAt != null) {
    buffer.writeln('');
  }
  buffer.writeln('Date,Name,Status,Donation');

  for (final tx in transactions) {
    buffer.writeln(
      [
        _csvValue(_formatDateTime(tx.timestamp)),
        _csvValue(_resolveUserName(userNames, tx.userId)),
        _csvValue(tx.status),
        _csvValue(_formatCurrency(tx.donationAmount)),
      ].join(','),
    );
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$title.csv');
  await file.writeAsString(buffer.toString());

  await Share.shareXFiles([XFile(file.path)], text: title);
}

Future<void> shareExpensesPdf({
  required String title,
  required List<Expense> expenses,
  required int totalExpenses,
  String? rangeLabel,
  DateTime? generatedAt,
}) async {
  final doc = pw.Document();
  final logoBytes = await rootBundle.load('assets/images/app_logo.png');
  final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
  final headers = ['Date', 'Category', 'Description', 'Amount'];
  final pageTheme = _buildWatermarkedTheme(logoImage);

  final categoryTotals = _sortedExpenseCategoryTotals(expenses);
  final categoryRows = categoryTotals.map((entry) {
    return [entry.key, _formatCurrency(entry.value)];
  }).toList();
  final data = expenses.map((expense) {
    return [
      _formatDateTime(expense.timestamp),
      expense.category,
      expense.description,
      _formatCurrency(expense.amount),
    ];
  }).toList();

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
              child: pw.Text(title, style: pw.TextStyle(fontSize: 18)),
            ),
          ],
        ),
        if (rangeLabel != null)
          pw.Text('Range: $rangeLabel', style: const pw.TextStyle()),
        if (generatedAt != null)
          pw.Text(
            'Generated: ${_formatDateTime(generatedAt)}',
            style: const pw.TextStyle(),
          ),
        pw.SizedBox(height: 12),
        pw.Text('Total expenses: ${_formatCurrency(totalExpenses)}'),
        pw.Text('Expenses: ${expenses.length}'),
        if (categoryRows.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text('Category totals', style: const pw.TextStyle()),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Category', 'Total'],
            data: categoryRows,
          ),
        ],
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(headers: headers, data: data),
      ],
    ),
  );

  await Printing.sharePdf(bytes: await doc.save(), filename: '$title.pdf');
}

Future<void> shareExpensesCsv({
  required String title,
  required List<Expense> expenses,
  String? rangeLabel,
  DateTime? generatedAt,
}) async {
  final buffer = StringBuffer();
  final categoryTotals = _sortedExpenseCategoryTotals(expenses);
  if (rangeLabel != null) {
    buffer.writeln('Report Range,${_csvValue(rangeLabel)}');
  }
  if (generatedAt != null) {
    buffer.writeln('Generated At,${_csvValue(_formatDateTime(generatedAt))}');
  }
  if (rangeLabel != null || generatedAt != null) {
    buffer.writeln('');
  }
  if (categoryTotals.isNotEmpty) {
    buffer.writeln('Category Totals');
    buffer.writeln('Category,Total');
    for (final entry in categoryTotals) {
      buffer.writeln(
        [
          _csvValue(entry.key),
          _csvValue(_formatCurrency(entry.value)),
        ].join(','),
      );
    }
    buffer.writeln('');
  }

  buffer.writeln('Expenses');
  buffer.writeln('Date,Category,Description,Amount');

  for (final expense in expenses) {
    buffer.writeln(
      [
        _csvValue(_formatDateTime(expense.timestamp)),
        _csvValue(expense.category),
        _csvValue(expense.description),
        _csvValue(_formatCurrency(expense.amount)),
      ].join(','),
    );
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$title.csv');
  await file.writeAsString(buffer.toString());

  await Share.shareXFiles([XFile(file.path)], text: title);
}
