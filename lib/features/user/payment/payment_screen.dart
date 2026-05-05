import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/constants/fee_rules.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _paymentService = PaymentService();
  final _donationController = TextEditingController();
  Razorpay? _razorpay;
  bool _busy = false;
  Timer? _debounce;
  Map<String, dynamic>? _preparedOrder;
  int? _preparedAmount;
  String? _currentTransactionId;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _paymentService.warmUp().catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _razorpay?.clear();
    _donationController.dispose();
    super.dispose();
  }

  int _parseDonationAmount() {
    final value = int.tryParse(_donationController.text.trim()) ?? 0;
    return value * 100;
  }

  Future<void> _prepareOrder() async {
    final donationAmount = _parseDonationAmount();
    if (donationAmount <= 0) {
      return;
    }

    try {
      final order = await _paymentService.createOrder(
        donationAmount: donationAmount,
      );
      _preparedOrder = order;
      _preparedAmount = donationAmount;
      _currentTransactionId = order['transactionId'];
      _currentOrderId = order['razorpay_order_id'];
    } catch (error) {
      _preparedOrder = null;
      _preparedAmount = null;
    }
  }

  void _schedulePrepare() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _prepareOrder);
  }

  Future<void> _startPayment() async {
    final donationAmount = _parseDonationAmount();
    if (donationAmount <= 0) {
      _showError('Enter a valid amount');
      return;
    }

    setState(() {
      _busy = true;
    });

    try {
      if (_preparedOrder == null || _preparedAmount != donationAmount) {
        await _prepareOrder();
      }

      final order = _preparedOrder;
      if (order == null) {
        throw StateError('Order creation failed');
      }

      final totalPaid = order['totalPaid'] as int;
      final fee = order['platformFee'] as int;

      final options = {
        'key': order['keyId'],
        'amount': totalPaid,
        'currency': order['currency'],
        'name': 'Trust Donation',
        'description': 'Donation payment',
        'order_id': _currentOrderId,
        'notes': {'platformFee': fee},
      };

      _razorpay?.open(options);
    } catch (error) {
      _showError('Could not start payment.');
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    if (_currentTransactionId == null || _currentOrderId == null) {
      _showError('Invalid transaction state.');
      return;
    }

    try {
      await _paymentService.verifyPayment(
        transactionId: _currentTransactionId!,
        razorpayOrderId: _currentOrderId!,
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment successful.')));
      }
      _preparedOrder = null;
      _preparedAmount = null;
      _currentTransactionId = null;
      _currentOrderId = null;
    } catch (error) {
      _showError('Payment verification failed.');
    }
  }

  void _handleError(PaymentFailureResponse response) async {
    if (_currentTransactionId != null) {
      await _paymentService.markPaymentFailed(
        transactionId: _currentTransactionId!,
      );
    }
    _preparedOrder = null;
    _preparedAmount = null;
    _currentTransactionId = null;
    _currentOrderId = null;
    _showError('Payment failed. Please try again.');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showError('External wallet selected: ${response.walletName ?? ''}.');
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final donationAmount = _parseDonationAmount();
    final fee = donationAmount > 0 ? FeeRules.platformFee(donationAmount) : 0;
    final totalPaid = donationAmount + fee;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donation amount (INR)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _donationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter amount in rupees',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) {
              setState(() {});
              _schedulePrepare();
            },
          ),
          const SizedBox(height: 16),
          Text('Platform fee: ${formatInr(fee)}'),
          Text('Total payable: ${formatInr(totalPaid)}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _startPayment,
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Pay with Razorpay'),
          ),
        ],
      ),
    );
  }
}
