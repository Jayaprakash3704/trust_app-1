import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

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
    final completer = Completer<RazorpayWebResult>();

    JSFunction? razorpayConstructor;
    try {
      final constructorAny = globalContext['Razorpay'];
      if (constructorAny is JSFunction) {
        razorpayConstructor = constructorAny;
      }
    } catch (_) {
      razorpayConstructor = null;
    }

    if (razorpayConstructor == null) {
      return Future.value(
        RazorpayWebResult.failed(
          description: 'Razorpay checkout is not available. Check checkout.js.',
        ),
      );
    }

    void completeOnce(RazorpayWebResult result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    final jsOptions = JSObject();
    jsOptions['key'] = key.toJS;
    jsOptions['amount'] = amount.toJS;
    jsOptions['currency'] = currency.toJS;
    jsOptions['name'] = name.toJS;
    jsOptions['description'] = description.toJS;
    jsOptions['order_id'] = orderId.toJS;

    if (notes != null && notes.isNotEmpty) {
      final notesObject = JSObject();
      for (final entry in notes.entries) {
        notesObject[entry.key] = _toJsAny(entry.value);
      }
      jsOptions['notes'] = notesObject;
    }

    jsOptions['handler'] = ((JSAny? response) {
      final paymentId = _readStringProperty(response, 'razorpay_payment_id');
      final confirmedOrderId = _readStringProperty(
        response,
        'razorpay_order_id',
      );
      final signature = _readStringProperty(response, 'razorpay_signature');

      if (paymentId == null || confirmedOrderId == null || signature == null) {
        completeOnce(
          RazorpayWebResult.failed(
            description: 'Missing payment confirmation details.',
          ),
        );
        return;
      }

      completeOnce(
        RazorpayWebResult.success(
          paymentId: paymentId,
          orderId: confirmedOrderId,
          signature: signature,
        ),
      );
    }).toJS;

    final modal = JSObject();
    modal['ondismiss'] = (() {
      completeOnce(RazorpayWebResult.cancelled());
    }).toJS;
    jsOptions['modal'] = modal;

    JSObject instance;
    try {
      instance = razorpayConstructor.callAsConstructor<JSObject>(jsOptions);
    } catch (error) {
      return Future.value(
        RazorpayWebResult.failed(description: error.toString()),
      );
    }

    try {
      instance.callMethodVarArgs('on'.toJS, [
        'payment.failed'.toJS,
        ((JSAny? response) {
          final errorObject = _readProperty(response, 'error');
          final code = _readStringProperty(errorObject, 'code');
          final description = _readStringProperty(errorObject, 'description');
          completeOnce(
            RazorpayWebResult.failed(
              code: code,
              description: description ?? 'Payment failed.',
            ),
          );
        }).toJS,
      ]);
    } catch (_) {}

    try {
      instance.callMethodVarArgs('open'.toJS);
    } catch (error) {
      completeOnce(RazorpayWebResult.failed(description: error.toString()));
    }

    return completer.future;
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

String? _readStringProperty(JSAny? source, String property) {
  if (source == null) {
    return null;
  }
  try {
    final object = source as JSObject;
    final value = object[property];
    if (value == null) {
      return null;
    }
    if (value.typeofEquals('string')) {
      return (value as JSString).toDart;
    }
    if (value.typeofEquals('number')) {
      return (value as JSNumber).toDartDouble.toString();
    }
    if (value.typeofEquals('boolean')) {
      return (value as JSBoolean).toDart.toString();
    }
    return value.toString();
  } catch (_) {
    return null;
  }
}

JSAny? _readProperty(JSAny? source, String property) {
  if (source == null) {
    return null;
  }
  try {
    final object = source as JSObject;
    return object[property];
  } catch (_) {
    return null;
  }
}

JSAny? _toJsAny(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value.toJS;
  }
  if (value is num) {
    return value.toJS;
  }
  if (value is bool) {
    return value.toJS;
  }
  return value.toString().toJS;
}
