import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Notifier that fires when a B12 notification is tapped.
  /// Listeners (e.g. home page) should navigate to the profile tab.
  static final ValueNotifier<bool> navigateToProfile =
      ValueNotifier<bool>(false);

  /// Notifier that fires when a vegan anniversary notification is tapped.
  /// Listeners (e.g. home page) should show the congratulation popup.
  static final ValueNotifier<bool> showAnniversary =
      ValueNotifier<bool>(false);

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone database
      tz.initializeTimeZones();

      // Get the device's local timezone
      final TimezoneInfo timeZoneInfos =
          await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfos.identifier));

      // Use default icon (app icon) for Android
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Explicitly create notification channel for Android
      await _createNotificationChannel();

      _isInitialized = true;

      // Handle cold start: app was launched by tapping a notification
      await _handleAppLaunchFromNotification();

      if (kDebugMode) {
        print('Notification service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing notification service: $e');
      }
      // Try to recover by canceling all notifications
      try {
        await _notifications.cancelAll();
        if (kDebugMode) {
          print('Cleared all notifications after initialization error');
        }
      } catch (clearError) {
        if (kDebugMode) {
          print('Failed to clear notifications: $clearError');
        }
      }
      _isInitialized = true; // Mark as initialized even with errors
    }
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const androidChannel = AndroidNotificationChannel(
          'b12_reminders',
          'Rappels B12',
          description:
              'Notifications pour les rappels de supplémentation en B12',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidPlugin.createNotificationChannel(androidChannel);

        const anniversaryChannel = AndroidNotificationChannel(
          'vegan_anniversary',
          'Véganniversaire',
          description:
              'Notifications pour célébrer votre anniversaire végane',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidPlugin.createNotificationChannel(anniversaryChannel);

        if (kDebugMode) {
          print('Notification channel created for Android');

          // Verify the channel was created
          final channels = await androidPlugin.getNotificationChannels();
          print('Available channels: ${channels?.map((c) => c.id).toList()}');
        }
      }
    }
  }

  /// Check if the app was launched by tapping a notification (cold start)
  Future<void> _handleAppLaunchFromNotification() async {
    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse != null) {
      final payload = launchDetails.notificationResponse!.payload ?? '';
      if (payload.startsWith('b12_reminder')) {
        navigateToProfile.value = true;
      } else if (payload.startsWith('vegan_anniversary')) {
        showAnniversary.value = true;
      }
    }
  }

  /// Handle notification tap or action button press
  void _onNotificationTap(NotificationResponse response) {
    if (kDebugMode) {
      print(
          'Notification tapped: ${response.payload}, actionId: ${response.actionId}');
    }

    final payload = response.payload ?? '';
    if (payload.startsWith('b12_reminder')) {
      // Signal listeners to navigate to the profile page
      navigateToProfile.value = true;
    } else if (payload.startsWith('vegan_anniversary')) {
      // Signal listeners to show the anniversary congratulation popup
      showAnniversary.value = true;
    }
  }

  /// Pick the Android schedule mode based on the exact-alarm permission.
  ///
  /// `SCHEDULE_EXACT_ALARM` is denied by default on Android 13+ (a distinct
  /// permission from POST_NOTIFICATIONS). Scheduling with
  /// [AndroidScheduleMode.exactAllowWhileIdle] without it throws a
  /// `PlatformException("exact_alarms_not_permitted")`. We fall back to the
  /// inexact mode so scheduling never throws 
  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final canExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return AndroidScheduleMode.exactAllowWhileIdle;
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 13+ requires runtime permission
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        // Request notification permission
        final granted = await androidPlugin.requestNotificationsPermission();
        if (kDebugMode) {
          print('Notification permission granted: $granted');
        }

        // Request exact alarm permission for Android 12+
        final canScheduleExact =
            await androidPlugin.canScheduleExactNotifications();
        if (kDebugMode) {
          print('Can schedule exact alarms: $canScheduleExact');
        }

        if (canScheduleExact == false) {
          final exactAlarmGranted =
              await androidPlugin.requestExactAlarmsPermission();
          if (kDebugMode) {
            print('Exact alarm permission granted: $exactAlarmGranted');
          }
        }

        return granted ?? false;
      }
      return true; // Older Android versions
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    return true;
  }

  /// Get notification details configuration
  NotificationDetails _getNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'b12_reminders',
      'Rappels B12',
      channelDescription:
          'Notifications pour les rappels de complémentation en B12',
      importance: Importance.high,
      priority: Priority.high,
      // Small white icon for status bar
      icon: 'ic_notification',
      // Large colored icon showing the app's logo
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Notification details for vegan anniversary notifications
  NotificationDetails _getAnniversaryNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'vegan_anniversary',
      'Véganniversaire',
      channelDescription:
          'Notifications pour célébrer votre anniversaire végane',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
      ongoing: false,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Schedule a yearly notification that repeats on the same date every year.
  Future<void> scheduleAnnualNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    final details = _getAnniversaryNotificationDetails();

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: await _androidScheduleMode(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: payload,
    );

    if (kDebugMode) {
      print('Scheduled annual notification for: $scheduledDate');
    }
  }

  /// Show an immediate test notification
  Future<void> showTestNotification() async {
    const title = '💊 Rappel B12';
    const body = 'Votre rappel a été configuré avec succès !';

    if (kDebugMode) {
      print('Showing immediate test notification');
    }

    final details = _getNotificationDetails();

    await _notifications.show(
      9999,
      title,
      body,
      details,
      payload: 'test_notification',
    );

    if (kDebugMode) {
      print('Test notification shown');
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? false;
      }
      return true;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }
    return true;
  }

  /// Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    String? payload,
  }) async {
    final details = _getNotificationDetails();

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: await _androidScheduleMode(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Schedule a daily notification
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time is in the past, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (kDebugMode) {
      print('Scheduling daily notification for: $scheduledDate');
    }

    final details = _getNotificationDetails();

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: await _androidScheduleMode(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );

    if (kDebugMode) {
      final pending = await getPendingNotifications();
      print('Pending notifications after scheduling: ${pending.length}');
    }
  }

  /// Schedule a weekly notification
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek, // 1 = Monday, 7 = Sunday
    required int hour,
    required int minute,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // Calculate days until target day
    int daysUntilTarget = (dayOfWeek - now.weekday) % 7;
    if (daysUntilTarget == 0) {
      // Same day - check if time has passed
      final todayScheduledTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      if (todayScheduledTime.isBefore(now)) {
        daysUntilTarget = 7; // Schedule for next week
      }
    }

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(days: daysUntilTarget));

    final details = _getNotificationDetails();

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: await _androidScheduleMode(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}
