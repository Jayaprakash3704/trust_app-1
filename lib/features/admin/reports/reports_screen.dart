import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/expense.dart';
import '../../../core/models/transaction.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/utils/report_exporter.dart';
import '../../../services/firestore_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firestoreService = FirestoreService();
  final _rangeFormat = DateFormat('dd MMM yyyy');
  final _fileDateFormat = DateFormat('yyyy-MM-dd');
  final _timestampFormat = DateFormat('yyyyMMdd-HHmmss');
  final _previewDateTimeFormat = DateFormat('dd MMM yyyy HH:mm');

  bool _busy = false;
  String _filter = 'this_month';
  String _reportType = 'transaction';
  DateTimeRange? _customRange;
  int _customYear = DateTime.now().year;
  String? _selectedUserId;

  List<DonationTransaction> _previewTransactions = [];
  List<Expense> _previewExpenses = [];
  List<MapEntry<String, int>> _previewExpenseCategoryTotals = [];
  Map<String, String> _previewUserNames = {};
  DateTimeRange? _previewRange;
  String? _previewTitle;
  String? _previewRangeLabel;
  DateTime? _previewGeneratedAt;
  int _previewTotalDonations = 0;
  int _previewTotalFees = 0;
  int _previewTotalPaid = 0;
  int _previewTotalExpenses = 0;

  List<int> _yearOptions() {
    final current = DateTime.now().year;
    return List.generate(6, (index) => current - index);
  }

  bool get _isExpenseReport => _reportType == 'expenses';
  bool get _isDonationReport => _reportType == 'donation';

  void _resetPreviewState() {
    _previewTransactions = [];
    _previewExpenses = [];
    _previewExpenseCategoryTotals = [];
    _previewUserNames = {};
    _previewRange = null;
    _previewTitle = null;
    _previewRangeLabel = null;
    _previewGeneratedAt = null;
    _previewTotalDonations = 0;
    _previewTotalFees = 0;
    _previewTotalPaid = 0;
    _previewTotalExpenses = 0;
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
        _resetPreviewState();
      });
    }
  }

  DateTimeRange? _resolveRange() {
    final now = DateTime.now();

    if (_filter == 'today') {
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }

    if (_filter == 'yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      final start = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final end = DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        23,
        59,
        59,
      );
      return DateTimeRange(start: start, end: end);
    }

    if (_filter == 'this_month') {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }

    if (_filter == 'this_year') {
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }

    if (_filter == 'custom_year') {
      final start = DateTime(_customYear, 1, 1);
      final end = DateTime(_customYear, 12, 31, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }

    if (_filter == 'custom_range') {
      if (_customRange == null) {
        return null;
      }
      final start = DateTime(
        _customRange!.start.year,
        _customRange!.start.month,
        _customRange!.start.day,
      );
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

    if (_filter == 'individual') {
      final start = DateTime(2000, 1, 1);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    }

    return null;
  }

  String _formatRange(DateTimeRange range) {
    return '${_rangeFormat.format(range.start)} - '
        '${_rangeFormat.format(range.end)}';
  }

  String _rangeToken(DateTimeRange range) {
    return '${_fileDateFormat.format(range.start)}_to_'
        '${_fileDateFormat.format(range.end)}';
  }

  String _buildExportTitle(
    DateTimeRange range,
    String? userId,
    String reportType,
  ) {
    final token = _rangeToken(range);
    final stamp = _timestampFormat.format(DateTime.now());
    final userToken = userId == null ? 'all' : 'user-$userId';
    return 'report-$reportType-$userToken-$token-$stamp';
  }

  Future<void> _generateReport() async {
    final range = _resolveRange();
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid date range.')),
      );
      return;
    }

    final usesUserFilter = !_isExpenseReport && _filter == 'individual';
    final userId = usesUserFilter ? _selectedUserId : null;
    if (usesUserFilter && userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a user first.')));
      return;
    }

    setState(() {
      _busy = true;
      _resetPreviewState();
    });

    try {
      if (_isExpenseReport) {
        final expenses = await _firestoreService.fetchExpenses(
          start: range.start,
          end: range.end,
        );

        if (!mounted) {
          return;
        }

        if (expenses.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No expenses for this report.')),
          );
          setState(() {
            _resetPreviewState();
          });
          return;
        }

        final totalExpenses = expenses.fold<int>(
          0,
          (sum, expense) => sum + expense.amount,
        );
        final categoryTotals = <String, int>{};
        for (final expense in expenses) {
          final rawCategory = expense.category.trim();
          final category = rawCategory.isEmpty ? 'Uncategorized' : rawCategory;
          categoryTotals[category] =
              (categoryTotals[category] ?? 0) + expense.amount;
        }
        final sortedCategoryTotals = categoryTotals.entries.toList()
          ..sort((a, b) {
            final byValue = b.value.compareTo(a.value);
            if (byValue != 0) {
              return byValue;
            }
            return a.key.compareTo(b.key);
          });

        final generatedAt = DateTime.now();
        final rangeLabel = _formatRange(range);
        final title = _buildExportTitle(range, null, _reportType);

        setState(() {
          _previewExpenses = expenses;
          _previewExpenseCategoryTotals = sortedCategoryTotals;
          _previewRange = range;
          _previewRangeLabel = rangeLabel;
          _previewGeneratedAt = generatedAt;
          _previewTitle = title;
          _previewTotalExpenses = totalExpenses;
        });
        return;
      }

      final transactions = await _firestoreService.fetchTransactions(
        start: range.start,
        end: range.end,
        status: 'success',
        userId: userId,
      );

      if (!mounted) {
        return;
      }

      if (transactions.isEmpty) {
        final emptyMessage = _isDonationReport
            ? 'No donations for this report.'
            : 'No transactions for this report.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(emptyMessage)));
        setState(() {
          _resetPreviewState();
        });
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

      final userIds = transactions
          .map((tx) => tx.userId)
          .where((id) => id.trim().isNotEmpty)
          .toSet();
      final userNames = await _firestoreService.fetchUserNamesByIds(userIds);

      if (_filter == 'this_year' || _filter == 'custom_year') {
        final totalUsers = await _firestoreService.fetchUserCount();
        await _firestoreService.createReport(
          year: range.start.year,
          totalRevenue: totalDonations,
          totalUsers: totalUsers,
        );
      }

      final generatedAt = DateTime.now();
      final rangeLabel = _formatRange(range);
      final title = _buildExportTitle(range, userId, _reportType);

      setState(() {
        _previewTransactions = transactions;
        _previewUserNames = userNames;
        _previewRange = range;
        _previewRangeLabel = rangeLabel;
        _previewGeneratedAt = generatedAt;
        _previewTitle = title;
        _previewTotalDonations = totalDonations;
        _previewTotalFees = totalFees;
        _previewTotalPaid = totalPaid;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _resetPreviewState();
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate report.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _exportPreview(bool pdf) async {
    final hasPreview = _isExpenseReport
        ? _previewExpenses.isNotEmpty
        : _previewTransactions.isNotEmpty;

    if (!hasPreview ||
        _previewTitle == null ||
        _previewRangeLabel == null ||
        _previewGeneratedAt == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generate a report first.')));
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      if (_isExpenseReport) {
        if (pdf) {
          await shareExpensesPdf(
            title: _previewTitle!,
            expenses: _previewExpenses,
            totalExpenses: _previewTotalExpenses,
            rangeLabel: _previewRangeLabel,
            generatedAt: _previewGeneratedAt,
          );
        } else {
          await shareExpensesCsv(
            title: _previewTitle!,
            expenses: _previewExpenses,
            rangeLabel: _previewRangeLabel,
            generatedAt: _previewGeneratedAt,
          );
        }
      } else if (_isDonationReport) {
        if (pdf) {
          await shareDonationsPdf(
            title: _previewTitle!,
            transactions: _previewTransactions,
            totalDonations: _previewTotalDonations,
            userNames: _previewUserNames,
            rangeLabel: _previewRangeLabel,
            generatedAt: _previewGeneratedAt,
          );
        } else {
          await shareDonationsCsv(
            title: _previewTitle!,
            transactions: _previewTransactions,
            userNames: _previewUserNames,
            rangeLabel: _previewRangeLabel,
            generatedAt: _previewGeneratedAt,
          );
        }
      } else {
        if (pdf) {
          await shareTransactionsPdf(
            title: _previewTitle!,
            transactions: _previewTransactions,
            totalDonations: _previewTotalDonations,
            totalFees: _previewTotalFees,
            totalPaid: _previewTotalPaid,
            userNames: _previewUserNames,
            rangeLabel: _previewRangeLabel,
            generatedAt: _previewGeneratedAt,
          );
        } else {
          await shareTransactionsCsv(
            title: _previewTitle!,
            transactions: _previewTransactions,
            userNames: _previewUserNames,
            rangeLabel: _previewRangeLabel,
            generatedAt: _previewGeneratedAt,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _formatTxDate(DateTime? date) {
    if (date == null) {
      return '-';
    }
    return _rangeFormat.format(date);
  }

  Widget _buildPreviewList() {
    if (_isExpenseReport) {
      final previewItems = _previewExpenses.take(10).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_previewExpenses.length > previewItems.length)
            Text(
              'Showing ${previewItems.length} of '
              '${_previewExpenses.length} expenses',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: previewItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final expense = previewItems[index];
              return ListTile(
                title: Text(formatInr(expense.amount)),
                subtitle: Text('${expense.category} • ${expense.description}'),
                trailing: Text(_formatTxDate(expense.timestamp)),
              );
            },
          ),
        ],
      );
    }

    final previewItems = _previewTransactions.take(10).toList();
    final showUserId = _filter != 'individual';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_previewTransactions.length > previewItems.length)
          Text(
            'Showing ${previewItems.length} of '
            '${_previewTransactions.length} '
            '${_isDonationReport ? 'donations' : 'transactions'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: previewItems.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final tx = previewItems[index];
            final name = _previewUserNames[tx.userId] ?? tx.userId;
            final subtitle = showUserId
              ? '${_formatTxDate(tx.timestamp)} • ${tx.status} • $name'
                : '${_formatTxDate(tx.timestamp)} • ${tx.status}';
            final amount = _isDonationReport ? tx.donationAmount : tx.totalPaid;
            return ListTile(
              title: Text(formatInr(amount)),
              subtitle: Text(subtitle),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExpenseCategoryBreakdown() {
    if (!_isExpenseReport || _previewExpenseCategoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category totals', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _previewExpenseCategoryTotals.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final entry = _previewExpenseCategoryTotals[index];
            return ListTile(
              dense: true,
              title: Text(entry.key),
              trailing: Text(formatInr(entry.value)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      key: const ValueKey('preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/app_logo.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text('Preview', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (_previewRangeLabel != null) Text('Range: $_previewRangeLabel'),
          if (_previewGeneratedAt != null)
            Text(
              'Generated: ${_previewDateTimeFormat.format(_previewGeneratedAt!)}',
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: _buildPreviewStats()),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _exportPreview(true),
                child: const Text('Export PDF'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _exportPreview(false),
                child: const Text('Export CSV'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isExpenseReport) ...[
            _buildExpenseCategoryBreakdown(),
            const SizedBox(height: 16),
          ],
          _buildPreviewList(),
        ],
      ),
    );
  }

  List<Widget> _buildPreviewStats() {
    if (_isExpenseReport) {
      return [
        _PreviewStat(
          label: 'Total expenses',
          value: formatInr(_previewTotalExpenses),
        ),
        _PreviewStat(
          label: 'Expenses',
          value: _previewExpenses.length.toString(),
        ),
      ];
    }

    if (_isDonationReport) {
      return [
        _PreviewStat(
          label: 'Total donations',
          value: formatInr(_previewTotalDonations),
        ),
        _PreviewStat(
          label: 'Donations',
          value: _previewTransactions.length.toString(),
        ),
      ];
    }

    return [
      _PreviewStat(
        label: 'Total donations',
        value: formatInr(_previewTotalDonations),
      ),
      _PreviewStat(label: 'Total fees', value: formatInr(_previewTotalFees)),
      _PreviewStat(label: 'Total paid', value: formatInr(_previewTotalPaid)),
      _PreviewStat(
        label: 'Transactions',
        value: _previewTransactions.length.toString(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview =
        _previewRange != null &&
        (_isExpenseReport
            ? _previewExpenses.isNotEmpty
            : _previewTransactions.isNotEmpty);

    final filterItems = <DropdownMenuItem<String>>[
      if (!_isExpenseReport)
        const DropdownMenuItem(value: 'individual', child: Text('Individual')),
      const DropdownMenuItem(value: 'this_year', child: Text('This year')),
      const DropdownMenuItem(value: 'custom_year', child: Text('Custom year')),
      const DropdownMenuItem(value: 'this_month', child: Text('This month')),
      const DropdownMenuItem(value: 'today', child: Text('Today')),
      const DropdownMenuItem(value: 'yesterday', child: Text('Yesterday')),
      const DropdownMenuItem(
        value: 'custom_range',
        child: Text('Custom range'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reports', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_reportType),
              initialValue: _reportType,
              items: const [
                DropdownMenuItem(
                  value: 'donation',
                  child: Text('Donation report'),
                ),
                DropdownMenuItem(
                  value: 'transaction',
                  child: Text('Transaction report'),
                ),
                DropdownMenuItem(
                  value: 'expenses',
                  child: Text('Expenses report'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _reportType = value;
                          if (_isExpenseReport && _filter == 'individual') {
                            _filter = 'this_month';
                            _selectedUserId = null;
                          }
                          _resetPreviewState();
                        });
                      }
                    },
              decoration: const InputDecoration(
                labelText: 'Report type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_filter),
              initialValue: _filter,
              items: filterItems,
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _filter = value;
                          _resetPreviewState();
                        });
                      }
                    },
              decoration: const InputDecoration(
                labelText: 'Filter',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_filter == 'custom_year')
              DropdownButtonFormField<int>(
                key: ValueKey(_customYear),
                initialValue: _customYear,
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
                    setState(() {
                      _customYear = value;
                      _resetPreviewState();
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
              ),
            if (_filter == 'custom_year') const SizedBox(height: 12),
            if (_filter == 'custom_range')
              OutlinedButton(
                onPressed: _busy ? null : _pickCustomRange,
                child: Text(
                  _customRange == null
                      ? 'Select range'
                      : _formatRange(
                          DateTimeRange(
                            start: _customRange!.start,
                            end: _customRange!.end,
                          ),
                        ),
                ),
              ),
            if (_filter == 'custom_range') const SizedBox(height: 12),
            if (!_isExpenseReport && _filter == 'individual')
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

                  final userIds = users.map((user) => user.uid).toSet();
                  final selectedUserId = userIds.contains(_selectedUserId)
                      ? _selectedUserId
                      : null;

                  if (_selectedUserId != null && selectedUserId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedUserId = null;
                        });
                      }
                    });
                  }

                  return DropdownButtonFormField<String>(
                    key: ValueKey(selectedUserId ?? 'none'),
                    initialValue: selectedUserId,
                    items: users
                        .map(
                          (user) => DropdownMenuItem(
                            value: user.uid,
                            child: Text(
                              user.name.isEmpty ? user.uid : user.name,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                        _resetPreviewState();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'User',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            if (!_isExpenseReport && _filter == 'individual')
              const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _generateReport,
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Generate report'),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
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
              child: hasPreview
                  ? _buildPreviewSection()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
