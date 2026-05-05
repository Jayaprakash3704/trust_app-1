import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../services/firestore_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
        if (transactions.isEmpty) {
          return const Center(child: Text('No transactions yet.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return ListTile(
              title: Text(formatInr(transaction.totalPaid)),
              subtitle: Text(
                '${transaction.status} • ${formatInr(transaction.donationAmount)}',
              ),
              trailing: Text(
                transaction.timestamp?.toLocal().toString().split('.').first ??
                    '',
              ),
            );
          },
          separatorBuilder: (context, index) => const Divider(),
          itemCount: transactions.length,
        );
      },
    );
  }
}
