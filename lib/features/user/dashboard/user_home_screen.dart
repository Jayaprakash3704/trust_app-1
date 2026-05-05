import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../services/firestore_service.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in.'));
    }

    return StreamBuilder(
      stream: FirestoreService().watchUserTransactions(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final transactions = snapshot.data ?? [];
        final successTx = transactions.where((tx) => tx.status == 'success');
        final totalDonations = successTx.fold<int>(
          0,
          (sum, tx) => sum + tx.donationAmount,
        );
        final totalPaid = successTx.fold<int>(
          0,
          (sum, tx) => sum + tx.totalPaid,
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
          ),
        );
      },
    );
  }
}
