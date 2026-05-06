import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/amount_formatter.dart';
import '../../../services/firestore_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _firestoreService = FirestoreService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _newCategoryController = TextEditingController();
  String? _selectedCategory;
  bool _busy = false;
  bool _categoryBusy = false;

  Future<void> _addExpense() async {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    final category = _selectedCategory?.trim() ?? '';
    if (category.isEmpty || _descriptionController.text.trim().isEmpty) {
      _showError('Category and description are required');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Not signed in');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      await _firestoreService.addExpense(
        amountPaise: amount * 100,
        description: _descriptionController.text.trim(),
        category: category,
        createdBy: user.uid,
      );

      _amountController.clear();
      _descriptionController.clear();
    } catch (error) {
      _showError('Could not add expense');
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) {
      _showError('Enter a category name');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Not signed in');
      return;
    }

    setState(() {
      _categoryBusy = true;
    });

    try {
      await _firestoreService.addExpenseCategory(
        name: name,
        createdBy: user.uid,
      );
      _newCategoryController.clear();
      setState(() {
        _selectedCategory = name;
      });
    } catch (error) {
      _showError('Could not add category');
    } finally {
      setState(() {
        _categoryBusy = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (INR)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<String>>(
                stream: _firestoreService.watchExpenseCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 56,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final categories = snapshot.data ?? [];
                  if (_selectedCategory != null &&
                      !categories.contains(_selectedCategory)) {
                    _selectedCategory = categories.isNotEmpty
                        ? categories.first
                        : null;
                  } else if (_selectedCategory == null &&
                      categories.isNotEmpty) {
                    _selectedCategory = categories.first;
                  }

                  if (categories.isEmpty) {
                    return const Text('No categories yet. Add one below.');
                  }

                  return DropdownButtonFormField<String>(
                    key: ValueKey(_selectedCategory ?? 'none'),
                    initialValue: _selectedCategory,
                    items: categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _selectedCategory = value),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newCategoryController,
                decoration: const InputDecoration(
                  labelText: 'New category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _categoryBusy ? null : _addCategory,
                child: _categoryBusy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _addExpense,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Expense'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder(
            stream: _firestoreService.watchExpenses(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final expenses = snapshot.data ?? [];
              if (expenses.isEmpty) {
                return const Center(child: Text('No expenses yet.'));
              }

              return ListView.separated(
                itemCount: expenses.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  return ListTile(
                    title: Text(formatInr(expense.amount)),
                    subtitle: Text(
                      '${expense.category} • ${expense.description}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          expense.timestamp
                                  ?.toLocal()
                                  .toString()
                                  .split('.')
                                  .first ??
                              '',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _firestoreService.deleteExpense(expense.id),
                        ),
                      ],
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
