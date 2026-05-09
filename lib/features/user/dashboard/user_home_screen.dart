import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/models/app_user.dart';
import '../../../core/widgets/monthly_basic_dialog.dart';
import '../../../services/firestore_service.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final _firestoreService = FirestoreService();
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

    await _firestoreService.updateUserMonthlyBasic(
      uid: currentUser.uid,
      amountPaise: result.amountPaise,
      dayOfMonth: result.dayOfMonth,
    );

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
    final summary = configured
        ? '${formatInr(amountPaise)} on day $day'
        : 'Not configured';

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in.'));
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, userSnapshot) {
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
