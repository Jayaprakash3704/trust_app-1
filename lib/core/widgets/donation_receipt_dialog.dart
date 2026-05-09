import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/amount_formatter.dart';
import '../utils/receipt_exporter.dart';

final _dateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

String _formatDate(DateTime? value) {
  if (value == null) {
    return '-';
  }
  return _dateTimeFormat.format(value);
}

String _statusHeadline(String status) {
  switch (status) {
    case 'success':
      return 'Payment successful';
    case 'pending':
      return 'Payment pending';
    case 'failed':
      return 'Payment failed';
    default:
      return 'Payment status: $status';
  }
}

Widget _detailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Future<void> showDonationReceiptDialog(
  BuildContext context,
  DonationReceiptData data,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(_statusHeadline(data.status)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(context, 'Name', data.donorName),
              _detailRow(context, 'Date', _formatDate(data.timestamp)),
              _detailRow(context, 'Status', data.status),
              _detailRow(context, 'Donation', formatInr(data.donationAmount)),
              _detailRow(context, 'Platform fee', formatInr(data.platformFee)),
              _detailRow(context, 'Total paid', formatInr(data.totalPaid)),
              if (data.transactionId != null && data.transactionId!.isNotEmpty)
                _detailRow(context, 'Transaction ID', data.transactionId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton.icon(
            onPressed: () => printDonationReceiptPdf(data),
            icon: const Icon(Icons.print),
            label: const Text('Print'),
          ),
          FilledButton.icon(
            onPressed: () => shareDonationReceiptPdf(data),
            icon: const Icon(Icons.share),
            label: const Text('Share PDF'),
          ),
        ],
      );
    },
  );
}
