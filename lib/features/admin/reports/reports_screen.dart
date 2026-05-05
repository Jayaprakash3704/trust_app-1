import 'package:flutter/material.dart';

import '../../../core/models/app_user.dart';
import '../../../core/utils/report_exporter.dart';
import '../../../services/firestore_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firestoreService = FirestoreService();
  bool _busy = false;
  int _customYear = DateTime.now().year;
  String? _selectedUserId;

  List<int> _yearOptions() {
    final current = DateTime.now().year;
    return List.generate(6, (index) => current - index);
  }

  Future<void> _exportRange({
    required String title,
    required DateTime start,
    required DateTime end,
    String? userId,
    required bool pdf,
    int? reportYear,
  }) async {
    setState(() {
      _busy = true;
    });

    try {
      final transactions = await _firestoreService.fetchTransactions(
        start: start,
        end: end,
        status: 'success',
        userId: userId,
      );

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No transactions for this report.')),
          );
        }
        return;
      }

      final totalDonations = transactions.fold<int>(
        0,
        (sum, tx) => sum + tx.donationAmount,
      );
      final totalFees = transactions.fold<int>(
        0,
        (sum, tx) => sum + tx.platformFee,
      );
      final totalPaid = transactions.fold<int>(
        0,
        (sum, tx) => sum + tx.totalPaid,
      );

      if (reportYear != null) {
        final totalUsers = await _firestoreService.fetchUserCount();
        await _firestoreService.createReport(
          year: reportYear,
          totalRevenue: totalDonations,
          totalUsers: totalUsers,
        );
      }

      if (pdf) {
        await shareTransactionsPdf(
          title: title,
          transactions: transactions,
          totalDonations: totalDonations,
          totalFees: totalFees,
          totalPaid: totalPaid,
        );
      } else {
        await shareTransactionsCsv(title: title, transactions: transactions);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _exportCurrentYear(bool pdf) async {
    final year = DateTime.now().year;
    await _exportRange(
      title: 'report-$year',
      start: DateTime(year, 1, 1),
      end: DateTime(year, 12, 31, 23, 59, 59),
      pdf: pdf,
      reportYear: year,
    );
  }

  Future<void> _exportCustomYear(bool pdf) async {
    await _exportRange(
      title: 'report-$_customYear',
      start: DateTime(_customYear, 1, 1),
      end: DateTime(_customYear, 12, 31, 23, 59, 59),
      pdf: pdf,
      reportYear: _customYear,
    );
  }

  Future<void> _exportUserReport(bool pdf) async {
    final userId = _selectedUserId;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a user first.')));
      return;
    }

    await _exportRange(
      title: 'user-$userId-report',
      start: DateTime(2000, 1, 1),
      end: DateTime.now(),
      userId: userId,
      pdf: pdf,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              'Current year',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _exportCurrentYear(true),
                  child: const Text('Export PDF'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _exportCurrentYear(false),
                  child: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Custom year', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButton<int>(
              value: _customYear,
              items: _yearOptions()
                  .map(
                    (year) => DropdownMenuItem(
                      value: year,
                      child: Text(year.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _customYear = value);
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _exportCustomYear(true),
                  child: const Text('Export PDF'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _exportCustomYear(false),
                  child: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Individual user',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<AppUser>>(
              stream: _firestoreService.watchUsers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const Text('No users found.');
                }

                return DropdownButton<String>(
                  value: _selectedUserId,
                  hint: const Text('Select user'),
                  items: users
                      .map(
                        (user) => DropdownMenuItem(
                          value: user.uid,
                          child: Text(user.name.isEmpty ? user.uid : user.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedUserId = value);
                  },
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _exportUserReport(true),
                  child: const Text('Export PDF'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _busy ? null : () => _exportUserReport(false),
                  child: const Text('Export CSV'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
