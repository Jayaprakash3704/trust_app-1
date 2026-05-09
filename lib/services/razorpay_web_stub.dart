class RazorpayWebCheckout {
  Future<RazorpayWebResult> open({
    required String key,
    required int amount,
    required String currency,
    required String name,
    required String description,
    required String orderId,
    Map<String, dynamic>? notes,
  }) {
    return Future.value(
      RazorpayWebResult.failed(
        description: 'Razorpay web checkout is not available on this platform.',
      ),
    );
  }
}

class RazorpayWebResult {
  RazorpayWebResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorCode,
    this.errorDescription,
  });

  final bool isSuccess;
  final bool isCancelled;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorCode;
  final String? errorDescription;

  factory RazorpayWebResult.success({
    required String paymentId,
    required String orderId,
    required String signature,
  }) {
    return RazorpayWebResult._(
      isSuccess: true,
      isCancelled: false,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  factory RazorpayWebResult.failed({String? code, String? description}) {
    return RazorpayWebResult._(
      isSuccess: false,
      isCancelled: false,
      errorCode: code,
      errorDescription: description,
    );
  }

  factory RazorpayWebResult.cancelled() {
    return RazorpayWebResult._(isSuccess: false, isCancelled: true);
  }
}
