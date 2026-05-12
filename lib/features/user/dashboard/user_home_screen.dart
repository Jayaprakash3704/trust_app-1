import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/models/app_user.dart';
import '../../../core/widgets/monthly_basic_dialog.dart';
import '../../../services/notification_service.dart';
import '../../../services/firestore_service.dart';

final _dueDateFormat = DateFormat('dd MMM yyyy');

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key, this.onDonateTap});

  final VoidCallback? onDonateTap;

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final _firestoreService = FirestoreService();
  final _notificationService = NotificationService.instance;
  bool _showHeader = false;
  int? _lastReminderAmount;
  int? _lastReminderDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _showHeader = true);
      }
    });
  }

  Widget _buildHeader(BuildContext context) {
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
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text('Your summary', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }

  int _defaultDay() {
    final day = DateTime.now().day;
    if (day < 1) {
      return 1;
    }
    if (day > 28) {
      return 28;
    }
    return day;
  }

  DateTime _nextDueDate(int dayOfMonth) {
    final safeDay = dayOfMonth.clamp(1, 28).toInt();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var due = DateTime(now.year, now.month, safeDay);
    if (due.isBefore(today)) {
      due = DateTime(now.year, now.month + 1, safeDay);
    }
    return due;
  }

  String _dueStatusLabel(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final days = dueDay.difference(today).inDays;
    if (days <= 0) {
      return 'Due today';
    }
    if (days == 1) {
      return 'Due in 1 day';
    }
    return 'Due in $days days';
  }

  int _daysUntilDue(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.difference(today).inDays;
  }

  String _dueReminderTitle(int days) {
    if (days <= 0) {
      return 'Monthly basic due today';
    }
    if (days == 1) {
      return 'Monthly basic due in 1 day';
    }
    return 'Monthly basic due in $days days';
  }

  Widget? _buildMonthlyDueReminder(AppUser? user) {
    if (user == null) {
      return null;
    }

    final amountPaise = user.monthlyBasicAmount;
    if (amountPaise <= 0) {
      return null;
    }

    final dueDate = _nextDueDate(user.monthlyBasicDay);
    final days = _daysUntilDue(dueDate);
    if (days > 3) {
      return null;
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_active, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dueReminderTitle(days),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('Amount: ${formatInr(amountPaise)}'),
                  Text('Due date: ${_dueDateFormat.format(dueDate)}'),
                  if (widget.onDonateTap != null)
                    TextButton(
                      onPressed: widget.onDonateTap,
                      child: const Text('Go to Donate'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMonthlyBasic(AppUser? user) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final initial = MonthlyBasicConfig(
      amountPaise: user?.monthlyBasicAmount ?? 0,
      dayOfMonth: user?.monthlyBasicDay ?? _defaultDay(),
    );
    final result = await showMonthlyBasicDialog(context, initial: initial);
    if (result == null) {
      return;
    }

    try {
      await _firestoreService.updateUserMonthlyBasic(
        uid: currentUser.uid,
        amountPaise: result.amountPaise,
        dayOfMonth: result.dayOfMonth,
      );

      _lastReminderAmount = result.amountPaise;
      _lastReminderDay = result.dayOfMonth;
      await _notificationService.scheduleMonthlyDueReminders(
        amountPaise: result.amountPaise,
        dayOfMonth: result.dayOfMonth,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save monthly basic.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Monthly basic saved.')));
  }

  Widget _buildMonthlyBasicCard(AppUser? user, {required bool loading}) {
    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    final amountPaise = user?.monthlyBasicAmount ?? 0;
    final day = user?.monthlyBasicDay ?? _defaultDay();
    final configured = amountPaise > 0;
    final summary = configured ? formatInr(amountPaise) : 'Not configured';
    final dueDate = configured ? _nextDueDate(day) : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly basic',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(summary),
            if (configured && dueDate != null) ...[
              const SizedBox(height: 6),
              Text('Next due: ${_dueDateFormat.format(dueDate)}'),
              Text(
                _dueStatusLabel(dueDate),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _editMonthlyBasic(user),
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }

  void _syncMonthlyReminders(AppUser? user) {
    if (user == null) {
      return;
    }

    final amount = user.monthlyBasicAmount;
    final day = user.monthlyBasicDay;
    if (amount == _lastReminderAmount && day == _lastReminderDay) {
      return;
    }

    _lastReminderAmount = amount;
    _lastReminderDay = day;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService
          .scheduleMonthlyDueReminders(amountPaise: amount, dayOfMonth: day)
          .catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in.'));
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, userSnapshot) {
        _syncMonthlyReminders(userSnapshot.data);
        final dueReminder = _buildMonthlyDueReminder(userSnapshot.data);

        return StreamBuilder(
          stream: _firestoreService.watchUserTransactions(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final transactions = snapshot.data ?? [];
            final successTx = transactions.where(
              (tx) => tx.status == 'success',
            );
            final totalDonations = successTx.fold<int>(
              0,
              (sum, tx) => sum + tx.donationAmount,
            );
            final totalPaid = successTx.fold<int>(
              0,
              (sum, tx) => sum + tx.totalPaid,
            );

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
              child: Padding(
                key: ValueKey('summary-${transactions.length}'),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 16),
                    if (dueReminder != null) ...[
                      dueReminder,
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Total donated',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatInr(totalDonations),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    Text('Total paid: ${formatInr(totalPaid)}'),
                    const SizedBox(height: 16),
                    Text('Successful donations: ${successTx.length}'),
                    const SizedBox(height: 24),
                    _buildMonthlyBasicCard(
                      userSnapshot.data,
                      loading:
                          userSnapshot.connectionState ==
                          ConnectionState.waiting,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
