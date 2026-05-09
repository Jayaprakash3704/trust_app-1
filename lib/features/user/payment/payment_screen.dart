import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/fee_rules.dart';
import '../../../core/utils/amount_formatter.dart';
import '../../../core/widgets/donation_receipt_dialog.dart';
import '../../../core/widgets/monthly_basic_dialog.dart';
import '../../../core/utils/receipt_exporter.dart';
import '../../../services/firestore_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/razorpay_web_service.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _paymentService = PaymentService();
  final _firestoreService = FirestoreService();
  final RazorpayWebCheckout _razorpayWeb = RazorpayWebCheckout();
  final _donationController = TextEditingController();
  final _uuid = const Uuid();
  Razorpay? _razorpay;
  bool _busy = false;
  Timer? _debounce;
  Map<String, dynamic>? _preparedOrder;
  int? _preparedAmount;
  String? _currentTransactionId;
  String? _currentOrderId;
  String? _currentClientRequestId;
  String? _lastPrepareError;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
      _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
      _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
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

    if (_currentClientRequestId == null || _preparedAmount != donationAmount) {
      _currentClientRequestId = _uuid.v4();
    }

    try {
      final order = await _paymentService.createOrder(
        donationAmount: donationAmount,
        clientRequestId: _currentClientRequestId,
      );
      _preparedOrder = order;
      _preparedAmount = donationAmount;
      _currentTransactionId = order['transactionId'];
      _currentOrderId = order['razorpay_order_id'];
      _lastPrepareError = null;
    } catch (error) {
      _preparedOrder = null;
      _preparedAmount = null;
      _lastPrepareError = _formatError(error);
    }
  }

  void _resetOrderState() {
    _preparedOrder = null;
    _preparedAmount = null;
    _currentTransactionId = null;
    _currentOrderId = null;
    _currentClientRequestId = null;
    _lastPrepareError = null;
  }

  Future<void> _completePayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    if (_currentTransactionId == null || _currentOrderId == null) {
      _showError('Invalid transaction state.');
      return;
    }

    final resolvedOrderId = orderId.isNotEmpty ? orderId : _currentOrderId!;
    if (paymentId.isEmpty || signature.isEmpty || resolvedOrderId.isEmpty) {
      _showError('Missing payment confirmation details.');
      return;
    }

    try {
      final status = await _paymentService.verifyPayment(
        transactionId: _currentTransactionId!,
        razorpayOrderId: resolvedOrderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'pending'
                  ? 'Payment submitted. Confirmation pending.'
                  : 'Payment successful.',
            ),
          ),
        );
      }

      final receipt = await _buildReceiptData(status);
      if (mounted) {
        await showDonationReceiptDialog(context, receipt);
      }

      if (mounted) {
        await _promptMonthlyBasic();
      }

      _resetOrderState();
    } catch (error) {
      _showError('Payment verification failed.');
    }
  }

  Future<DonationReceiptData> _buildReceiptData(String status) async {
    final transactionId = _currentTransactionId;
    final donationAmount = _preparedAmount ?? _parseDonationAmount();
    final platformFee = FeeRules.platformFee(donationAmount);
    final totalPaid = donationAmount + platformFee;

    DonationReceiptData fallbackReceipt() {
      final user = FirebaseAuth.instance.currentUser;
      return DonationReceiptData(
        donorName: user?.displayName ?? user?.email ?? 'Member',
        donationAmount: donationAmount,
        platformFee: platformFee,
        totalPaid: totalPaid,
        status: status,
        timestamp: DateTime.now(),
        transactionId: transactionId,
      );
    }

    if (transactionId == null) {
      return fallbackReceipt();
    }

    final transaction = await _firestoreService.fetchTransaction(transactionId);
    final currentUser = FirebaseAuth.instance.currentUser;
    final appUser = currentUser == null
        ? null
        : await _firestoreService.fetchUser(currentUser.uid);

    final resolvedStatus = transaction?.status == 'created'
        ? status
        : (transaction?.status ?? status);
    final resolvedDonation = transaction?.donationAmount ?? donationAmount;
    final resolvedFee =
        transaction?.platformFee ?? FeeRules.platformFee(resolvedDonation);
    final resolvedTotal =
        transaction?.totalPaid ?? (resolvedDonation + resolvedFee);

    return DonationReceiptData(
      donorName:
          appUser?.name ??
          currentUser?.displayName ??
          currentUser?.email ??
          'Member',
      donationAmount: resolvedDonation,
      platformFee: resolvedFee,
      totalPaid: resolvedTotal,
      status: resolvedStatus,
      timestamp: transaction?.timestamp ?? DateTime.now(),
      transactionId: transactionId,
    );
  }

  Future<void> _promptMonthlyBasic() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final appUser = await _firestoreService.fetchUser(currentUser.uid);
    final today = DateTime.now().day;
    final defaultDay = today < 1 ? 1 : (today > 28 ? 28 : today);
    final initial = MonthlyBasicConfig(
      amountPaise: appUser?.monthlyBasicAmount ?? 0,
      dayOfMonth: appUser?.monthlyBasicDay ?? defaultDay,
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

  Future<void> _handleWebResult(RazorpayWebResult result) async {
    if (result.isSuccess) {
      await _completePayment(
        paymentId: result.paymentId ?? '',
        orderId: result.orderId ?? '',
        signature: result.signature ?? '',
      );
      return;
    }

    if (_currentTransactionId != null) {
      await _paymentService.markPaymentFailed(
        transactionId: _currentTransactionId!,
      );
    }

    _resetOrderState();

    if (result.isCancelled) {
      _showError('Payment cancelled.');
      return;
    }

    final description = result.errorDescription;
    _showError(
      description != null && description.trim().isNotEmpty
          ? description
          : 'Payment failed. Please try again.',
    );
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
        _showError(_lastPrepareError ?? 'Order creation failed.');
        return;
      }

      final orderId = _currentOrderId;
      if (orderId == null || orderId.isEmpty) {
        throw StateError('Order ID missing');
      }

      final totalPaid = order['totalPaid'] as int;
      final fee = order['platformFee'] as int;
      final currency = (order['currency'] ?? 'INR').toString();

      final options = {
        'key': order['keyId'],
        'amount': totalPaid,
        'currency': currency,
        'name': 'Trust Donation',
        'description': 'Donation payment',
        'order_id': orderId,
        'notes': {'platformFee': fee},
      };

      if (kIsWeb) {
        final result = await _razorpayWeb.open(
          key: (options['key'] ?? '').toString(),
          amount: totalPaid,
          currency: currency,
          name: 'Trust Donation',
          description: 'Donation payment',
          orderId: orderId,
          notes: {'platformFee': fee},
        );
        await _handleWebResult(result);
        return;
      }

      _razorpay?.open(options);
    } catch (error) {
      _showError(_formatError(error));
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  String _formatError(Object error) {
    if (error is StateError) {
      return error.message;
    }
    final message = error.toString();
    return message.replaceFirst('Exception: ', '').trim();
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    await _completePayment(
      paymentId: response.paymentId ?? '',
      orderId: response.orderId ?? _currentOrderId ?? '',
      signature: response.signature ?? '',
    );
  }

  void _handleError(PaymentFailureResponse response) async {
    if (_currentTransactionId != null) {
      await _paymentService.markPaymentFailed(
        transactionId: _currentTransactionId!,
      );
    }
    _resetOrderState();
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
