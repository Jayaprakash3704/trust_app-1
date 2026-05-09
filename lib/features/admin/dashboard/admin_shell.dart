import 'package:flutter/material.dart';

import '../members/members_screen.dart';
import '../reports/reports_screen.dart';
import '../transactions/transactions_screen.dart';
import '../expenses/expenses_screen.dart';
import '../../../core/widgets/app_watermark.dart';
import '../../../services/auth_service.dart';
import 'admin_dashboard_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            onPressed: () => AuthService().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppWatermark(),
          IndexedStack(
            index: _index,
            children: const [
              AdminDashboardScreen(),
              MembersScreen(),
              TransactionsScreen(),
              ExpensesScreen(),
              ReportsScreen(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.insights), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Members'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.file_present),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}
