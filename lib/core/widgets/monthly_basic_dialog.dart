import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MonthlyBasicConfig {
  const MonthlyBasicConfig({
    required this.amountPaise,
    required this.dayOfMonth,
  });

  final int amountPaise;
  final int dayOfMonth;
}

int _defaultDay() {
  final today = DateTime.now().day;
  if (today < 1) {
    return 1;
  }
  if (today > 28) {
    return 28;
  }
  return today;
}

Future<MonthlyBasicConfig?> showMonthlyBasicDialog(
  BuildContext context, {
  MonthlyBasicConfig? initial,
}) async {
  final config = initial ?? MonthlyBasicConfig(amountPaise: 0, dayOfMonth: 1);
  final amountController = TextEditingController(
    text: config.amountPaise > 0 ? (config.amountPaise ~/ 100).toString() : '',
  );
  int selectedDay = config.dayOfMonth > 0 ? config.dayOfMonth : _defaultDay();
  String? amountError;

  final result = await showDialog<MonthlyBasicConfig>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Monthly basic settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Amount (INR)',
                    hintText: 'Enter monthly amount',
                    helperText: 'Set 0 to disable.',
                    errorText: amountError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (amountError != null) {
                      setState(() => amountError = null);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedDay,
                  decoration: const InputDecoration(
                    labelText: 'Due day of month',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    28,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('Day ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      selectedDay = value;
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Skip'),
              ),
              FilledButton(
                onPressed: () {
                  final raw = amountController.text.trim();
                  if (raw.isEmpty) {
                    setState(
                      () => amountError = 'Enter amount or 0 to disable.',
                    );
                    return;
                  }

                  final amount = int.tryParse(raw);
                  if (amount == null) {
                    setState(() => amountError = 'Enter a valid number.');
                    return;
                  }

                  final amountPaise = amount * 100;
                  Navigator.of(context).pop(
                    MonthlyBasicConfig(
                      amountPaise: amountPaise,
                      dayOfMonth: selectedDay,
                    ),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  amountController.dispose();
  return result;
}
