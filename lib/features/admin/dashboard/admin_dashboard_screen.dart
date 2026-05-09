import 'package:flutter/material.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../services/firestore_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestoreService = FirestoreService();
  String _filter = 'month';
  DateTimeRange? _customRange;
  bool _showHeader = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showHeader = true);
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
      });
    }
  }

  DateTimeRange _resolveRange() {
    final now = DateTime.now();
    if (_filter == 'custom' && _customRange != null) {
      final start = _customRange!.start;
      final end = DateTime(
        _customRange!.end.year,
        _customRange!.end.month,
        _customRange!.end.day,
        23,
        59,
        59,
      );
      return DateTimeRange(start: start, end: end);
    }

    if (_filter == 'year') {
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }

    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateTimeRange(start: start, end: end);
  }

  Widget _buildHeader() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: _showHeader ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        offset: _showHeader ? Offset.zero : const Offset(0, -0.08),
        child: Row(
          children: [
            Image.asset(
              'assets/images/app_logo.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              'Admin dashboard',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _resolveRange();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Row(
            children: [
              DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'month', child: Text('This month')),
                  DropdownMenuItem(value: 'year', child: Text('This year')),
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom range'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _filter = value);
                  }
                },
              ),
              const SizedBox(width: 12),
              if (_filter == 'custom')
                OutlinedButton(
                  onPressed: _pickCustomRange,
                  child: Text(
                    _customRange == null
                        ? 'Select range'
                        : '${range.start.toLocal().toString().split(' ').first} - '
                              '${range.end.toLocal().toString().split(' ').first}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: _firestoreService.fetchTransactions(
              start: range.start,
              end: range.end,
              status: 'success',
            ),
            builder: (context, snapshot) {
              Widget child;
              if (snapshot.connectionState == ConnectionState.waiting) {
                child = const Center(
                  key: ValueKey('loading'),
                  child: CircularProgressIndicator(),
                );
              } else if (snapshot.hasError) {
                child = const Text(
                  'Failed to load totals.',
                  key: ValueKey('error'),
                );
              } else {
                final transactions = snapshot.data ?? [];
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

                child = Wrap(
                  key: ValueKey('stats-${transactions.length}'),
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      label: 'Total donations',
                      value: formatInr(totalDonations),
                    ),
                    _StatCard(label: 'Total fees', value: formatInr(totalFees)),
                    _StatCard(label: 'Total paid', value: formatInr(totalPaid)),
                    _StatCard(
                      label: 'Successful transactions',
                      value: transactions.length.toString(),
                    ),
                  ],
                );
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 0.04),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: child,
              );
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder(
            future: _firestoreService.fetchMemberCount(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              final count = snapshot.data ?? 0;
              return Text('Total members: $count');
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}
