import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_config.dart';

class BackendWarmupInfo {
  const BackendWarmupInfo({
    required this.latency,
    this.uptimeSeconds,
    this.startedAt,
  });

  final Duration latency;
  final int? uptimeSeconds;
  final DateTime? startedAt;
}

class BackendWarmup {
  BackendWarmup._();

  static final BackendWarmup instance = BackendWarmup._();

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const Duration _defaultTimeout = Duration(seconds: 25);

  DateTime? _lastSuccessAt;
  BackendWarmupInfo? _lastInfo;
  Future<BackendWarmupInfo>? _inflight;

  BackendWarmupInfo? get lastInfo => _lastInfo;

  bool get isWarm {
    final last = _lastSuccessAt;
    if (last == null) {
      return false;
    }
    return DateTime.now().difference(last) < _cacheDuration;
  }

  Future<BackendWarmupInfo> ensureWarm({
    bool force = false,
    Duration timeout = _defaultTimeout,
  }) async {
    if (!force && isWarm && _lastInfo != null) {
      return _lastInfo!;
    }

    if (_inflight != null) {
      return _inflight!;
    }

    final task = _warmUp(timeout);
    _inflight = task;
    try {
      final info = await task;
      _lastSuccessAt = DateTime.now();
      _lastInfo = info;
      return info;
    } finally {
      _inflight = null;
    }
  }

  Future<BackendWarmupInfo> _warmUp(Duration timeout) async {
    final start = DateTime.now();
    http.Response response;

    try {
      response = await http
          .get(Uri.parse('${AppConfig.backendBaseUrl}/health'))
          .timeout(timeout);
    } on TimeoutException {
      throw StateError('Backend warm-up timed out.');
    } on http.ClientException {
      throw StateError('Backend unreachable. Check BACKEND_BASE_URL.');
    } catch (_) {
      throw StateError('Backend warm-up failed.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Backend health check failed (${response.statusCode}).');
    }

    int? uptimeSeconds;
    DateTime? startedAt;

    if (response.body.isNotEmpty) {
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map) {
          final rawUptime = payload['uptimeSeconds'];
          if (rawUptime is int) {
            uptimeSeconds = rawUptime;
          } else if (rawUptime is num) {
            uptimeSeconds = rawUptime.toInt();
          }

          final rawStartedAt = payload['startedAt'];
          if (rawStartedAt is String) {
            startedAt = DateTime.tryParse(rawStartedAt);
          }
        }
      } catch (_) {}
    }

    final latency = DateTime.now().difference(start);
    return BackendWarmupInfo(
      latency: latency,
      uptimeSeconds: uptimeSeconds,
      startedAt: startedAt,
    );
  }
}
