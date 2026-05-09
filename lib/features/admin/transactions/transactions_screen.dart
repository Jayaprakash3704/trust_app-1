import 'package:flutter/material.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../services/firestore_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _firestoreService = FirestoreService();
  String _statusFilter = 'all';
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() {
        _range = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _range?.start;
    final end = _range == null
        ? null
        : DateTime(
            _range!.end.year,
            _range!.end.month,
            _range!.end.day,
            23,
            59,
            59,
          );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'success', child: Text('Success')),
                  DropdownMenuItem(value: 'failed', child: Text('Failed')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _statusFilter = value);
                  }
                },
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _pickRange,
                child: Text(
                  _range == null
                      ? 'Select date range'
                      : '${_range!.start.toLocal().toString().split(' ').first} - '
                            '${_range!.end.toLocal().toString().split(' ').first}',
                ),
              ),
              if (_range != null)
                IconButton(
                  onPressed: () => setState(() => _range = null),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _firestoreService.fetchTransactions(
              start: start,
              end: end,
              status: _statusFilter == 'all' ? null : _statusFilter,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text('Failed to load transactions.'),
                );
              }

              final transactions = snapshot.data ?? [];
              if (transactions.isEmpty) {
                return const Center(child: Text('No transactions found.'));
              }

              return ListView.separated(
                itemCount: transactions.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return ListTile(
                    title: Text(formatInr(tx.totalPaid)),
                    subtitle: Text(tx.status),
                    trailing: Text(
                      tx.timestamp?.toLocal().toString().split('.').first ?? '',
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
