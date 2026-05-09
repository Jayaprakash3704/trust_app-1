import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/donation_receipt_dialog.dart';
import '../../../core/utils/receipt_exporter.dart';
import '../../../core/models/app_user.dart';
import '../../../services/firestore_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in.'));
    }

    final firestoreService = FirestoreService();

    return StreamBuilder<AppUser?>(
      stream: firestoreService.watchUser(user.uid),
      builder: (context, userSnapshot) {
        final displayName =
            userSnapshot.data?.name ??
            user.displayName ??
            user.email ??
            'Member';

        return StreamBuilder(
          stream: firestoreService.watchUserTransactions(user.uid),
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
                    transaction.timestamp
                            ?.toLocal()
                            .toString()
                            .split('.')
                            .first ??
                        '',
                  ),
                  onTap: () {
                    final receipt = DonationReceiptData(
                      donorName: displayName,
                      donationAmount: transaction.donationAmount,
                      platformFee: transaction.platformFee,
                      totalPaid: transaction.totalPaid,
                      status: transaction.status,
                      timestamp: transaction.timestamp,
                      transactionId: transaction.id,
                    );
                    showDonationReceiptDialog(context, receipt);
                  },
                );
              },
              separatorBuilder: (context, index) => const Divider(),
              itemCount: transactions.length,
            );
          },
        );
      },
    );
  }
}
