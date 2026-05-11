import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/amount_formatter.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int _baseId = 4100;
  static const int _maxMonths = 3;
  static const List<int> _leadDays = [2, 1, 0];

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Future<void>? _initFuture;
  bool _permissionsRequested = false;

  Future<void> _ensureInitialized() {
    if (_initFuture != null) {
      return _initFuture!;
    }
    _initFuture = _initialize();
    return _initFuture!;
  }

  Future<void> _initialize() async {
    if (kIsWeb) {
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _notifications.initialize(settings: settings);
    await _configureLocalTimeZone();
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<void> _requestPermissions() async {
    if (_permissionsRequested) {
      return;
    }
    _permissionsRequested = true;

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleMonthlyDueReminders({
    required int amountPaise,
    required int dayOfMonth,
    int hour = 9,
    int minute = 0,
  }) async {
    if (kIsWeb) {
      return;
    }

    await _ensureInitialized();
    await _requestPermissions();
    await cancelMonthlyDueReminders();

    if (amountPaise <= 0) {
      return;
    }

    final now = DateTime.now();
    final safeDay = dayOfMonth.clamp(1, 28).toInt();
    var baseDue = DateTime(now.year, now.month, safeDay, hour, minute);
    if (!baseDue.isAfter(now)) {
      baseDue = DateTime(now.year, now.month + 1, safeDay, hour, minute);
    }

    final details = _notificationDetails();

    for (var monthIndex = 0; monthIndex < _maxMonths; monthIndex += 1) {
      final dueDate = DateTime(
        baseDue.year,
        baseDue.month + monthIndex,
        safeDay,
        hour,
        minute,
      );

      for (
        var offsetIndex = 0;
        offsetIndex < _leadDays.length;
        offsetIndex += 1
      ) {
        final daysBefore = _leadDays[offsetIndex];
        final scheduled = dueDate.subtract(Duration(days: daysBefore));
        if (!scheduled.isAfter(now)) {
          continue;
        }

        final id = _baseId + monthIndex * 10 + offsetIndex;
        final title = _titleForLeadDays(daysBefore);
        final body = _bodyForReminder(amountPaise, dueDate);

        await _notifications.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'monthly_basic',
        );
      }
    }
  }

  Future<void> cancelMonthlyDueReminders() async {
    if (kIsWeb) {
      return;
    }

    await _ensureInitialized();

    for (var monthIndex = 0; monthIndex < _maxMonths; monthIndex += 1) {
      for (
        var offsetIndex = 0;
        offsetIndex < _leadDays.length;
        offsetIndex += 1
      ) {
        final id = _baseId + monthIndex * 10 + offsetIndex;
        await _notifications.cancel(id: id);
      }
    }
  }

  NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'monthly_basic_due',
      'Monthly due reminders',
      channelDescription: 'Reminders for monthly basic dues',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  String _titleForLeadDays(int daysBefore) {
    if (daysBefore <= 0) {
      return 'Monthly basic due today';
    }
    if (daysBefore == 1) {
      return 'Monthly basic due tomorrow';
    }
    return 'Monthly basic due in $daysBefore days';
  }

  String _bodyForReminder(int amountPaise, DateTime dueDate) {
    final dateLabel = DateFormat('dd MMM').format(dueDate);
    return 'Amount: ${formatInr(amountPaise)} • Due $dateLabel';
  }
}
