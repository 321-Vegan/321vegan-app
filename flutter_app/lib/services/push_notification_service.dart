// getToken/onTokenRefresh: see the class comment.
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'app_notification_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

/// A server push the user tapped, waiting for the home page to open it.
class OpenedPush {
  const OpenedPush({required this.notificationId, required this.type});

  final int notificationId;
  final String type;

  static const String _payloadPrefix = 'push_notification:';

  /// From the push data sent by the API (null if it isn't one of ours).
  static OpenedPush? fromData(Map<String, dynamic> data) {
    final id = int.tryParse('${data['notification_id']}');
    if (id == null) return null;
    return OpenedPush(notificationId: id, type: '${data['type'] ?? ''}');
  }

  /// Payload of the local notification showing a push in the foreground
  /// (Android), read back by [fromPayload] when it's tapped.
  String toPayload() => '$_payloadPrefix$notificationId:$type';

  static OpenedPush? fromPayload(String payload) {
    if (!payload.startsWith(_payloadPrefix)) return null;
    final rest = payload.substring(_payloadPrefix.length);
    final separator = rest.indexOf(':');
    if (separator < 0) return null;
    final id = int.tryParse(rest.substring(0, separator));
    if (id == null) return null;
    return OpenedPush(notificationId: id, type: rest.substring(separator + 1));
  }
}

/// Firebase Cloud Messaging: registers this device with the API
/// (POST /me/push-devices/) so the server can push the notifications of the
/// logged-in account, and routes taps on those pushes.
///
/// Uses the FCM registration token, which the API sends to. The token APIs
/// are deprecated in firebase_messaging 17 in favor of FID registration
/// (register/onRegistered); switch once the API sends by FID.
class PushNotificationService {
  PushNotificationService._();

  static const String _deviceIdKey = 'push_device_id';
  static const String _installationIdKey = 'push_installation_id';
  static const String _enabledKey = 'push_notifications_enabled';
  static const String _offerSnoozedAtKey = 'push_offer_snoozed_at';

  /// Delay before offering the pushes again after a signalement (see
  /// snoozeOffer).
  static const Duration _offerSnooze = Duration(days: 14);

  static bool _ready = false;

  /// OS permission at the last registration, to notice a change made from
  /// the phone settings (see _onResume).
  static bool? _allowed;

  /// Registration in progress, shared instead of running a second one.
  static Future<bool>? _registering;

  /// Set when a push is tapped; the home page opens the notification
  /// center and resets it.
  static final ValueNotifier<OpenedPush?> opened =
      ValueNotifier<OpenedPush?>(null);

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  static Future<void> init() async {
    try {
      // Config read from google-services.json / GoogleService-Info.plist
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init failed, pushes disabled: $e');
      return;
    }
    _ready = true;

    // Banner even when the app is open: iOS shows it itself once asked,
    // Android needs a local notification (see _onForegroundMessage)
    await _messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onOpened);
    // Through registerDevice: it checks the settings switch and the OS
    // permission (getToken then returns the new token)
    _messaging.onTokenRefresh.listen((_) {
      if (AuthService.isLoggedIn) registerDevice();
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) _onOpened(initial);

    AppLifecycleListener(onResume: _onResume);

    if (AuthService.isLoggedIn) unawaited(registerDevice());
  }

  /// Back in the app, e.g. from the phone settings: registers (or
  /// unregisters) this device if the OS permission changed meanwhile.
  static Future<void> _onResume() async {
    if (!AuthService.isLoggedIn) return;
    try {
      final allowed = _isAllowed(await _messaging.getNotificationSettings());
      if (allowed != _allowed) await registerDevice();
    } catch (e) {
      debugPrint('Push permission check failed: $e');
    }
  }

  /// False for pushes sent to a previous account of this device.
  static bool _isForCurrentUser(RemoteMessage message) {
    if (!AuthService.isLoggedIn) return false;
    final userId = AuthService.currentUser?.id;
    return userId == null || '${message.data['user_id']}' == '$userId';
  }

  static void _onForegroundMessage(RemoteMessage message) {
    AppNotificationService.refresh();
    final notification = message.notification;
    final push = OpenedPush.fromData(message.data);
    if (!Platform.isAndroid ||
        notification == null ||
        push == null ||
        !_isForCurrentUser(message)) {
      return;
    }
    NotificationService().showPush(
      push,
      title: notification.title ?? '',
      body: notification.body ?? '',
    );
  }

  static void _onOpened(RemoteMessage message) {
    final push = OpenedPush.fromData(message.data);
    if (push != null && _isForCurrentUser(message)) opened.value = push;
  }

  /// The "Notifications" switch of the settings (on unless turned off).
  static Future<bool> _isEnabledPref() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static bool _isAllowed(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  /// Whether pushes reach this device: switch on and OS permission given.
  static Future<bool> isEnabled() async {
    if (!_ready || !await _isEnabledPref()) return false;
    return _isAllowed(await _messaging.getNotificationSettings());
  }

  /// Whether asking the OS permission would enable the pushes: logged in,
  /// switch on, permission not given yet.
  static Future<bool> needsPermission() async {
    if (!_ready || !AuthService.isLoggedIn || !await _isEnabledPref()) {
      return false;
    }
    return !_isAllowed(await _messaging.getNotificationSettings());
  }

  /// Whether the offer after a signalement was declined (or the OS
  /// refused) less than [_offerSnooze] ago.
  static Future<bool> isOfferSnoozed() async {
    final prefs = await SharedPreferences.getInstance();
    final snoozedAt = prefs.getInt(_offerSnoozedAtKey);
    if (snoozedAt == null) return false;
    final elapsed = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(snoozedAt));
    return elapsed < _offerSnooze;
  }

  static Future<void> snoozeOffer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        _offerSnoozedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Registers this device for the logged-in account, if the settings
  /// switch is on and the OS permission granted.
  ///
  /// The permission is only asked when [prompt] is true, at a moment where
  /// it makes sense (accepting offerPushNotifications after a signalement,
  /// from the settings switch);
  /// app start and login just register silently if already granted.
  /// Returns whether the OS permission is given, even if the registration
  /// itself failed (e.g. no FCM token without Google services, /e/OS
  /// without microG push): not a refusal the user could fix.
  static Future<bool> registerDevice({bool prompt = false}) async {
    // One at a time: the OS prompt sends the app to the background and
    // back, so _onResume would otherwise register in parallel
    final running = _registering;
    if (running != null) {
      if (!prompt) return running;
      await running;
    }
    final registering = _registerDevice(prompt);
    _registering = registering;
    try {
      return await registering;
    } finally {
      if (identical(_registering, registering)) _registering = null;
    }
  }

  static Future<bool> _registerDevice(bool prompt) async {
    if (!_ready || !AuthService.isLoggedIn || !await _isEnabledPref()) {
      return false;
    }
    var allowed = false;
    try {
      final settings = prompt
          ? await _messaging.requestPermission()
          : await _messaging.getNotificationSettings();
      allowed = _isAllowed(settings);
      _allowed = allowed;
      if (!allowed) {
        // Refused (possibly later, from the OS settings): stop sending
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          await unregisterDevice();
        }
        return false;
      }
      final token = await _getToken();
      if (token != null) await _register(token);
      return true;
    } catch (e) {
      debugPrint('Push registration failed: $e');
      return allowed;
    }
  }

  /// Settings switch. Turning it on asks the OS permission if needed;
  /// returns the resulting state (false if the OS permission is refused).
  ///
  /// The pref keeps the user's choice even when the OS refuses: allowing
  /// later from the phone settings is then enough (see _onResume).
  static Future<bool> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (!enabled) {
      await unregisterDevice();
      return false;
    }
    return registerDevice(prompt: true);
  }

  static Future<String?> _getToken() async {
    if (Platform.isIOS) {
      // The FCM token needs the APNs one, which can arrive a bit after launch
      for (var i = 0; i < 10; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return _messaging.getToken();
  }

  static Future<void> _register(String token) async {
    final deviceId = await ApiService.registerPushDevice(
      platform: Platform.isIOS ? 'ios' : 'android',
      installationId: await _installationId(),
      token: token,
    );
    if (deviceId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deviceIdKey, deviceId);
  }

  /// Stable per-install ID: lets the API update this device's row when the
  /// token or the logged-in account changes, instead of adding one.
  static Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_installationIdKey);
    if (id == null) {
      final random = Random.secure();
      id = List.generate(16, (_) => random.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await prefs.setString(_installationIdKey, id);
    }
    return id;
  }

  /// Stops the pushes of the logged-in account on this device. Must run
  /// before the access token is cleared.
  static Future<void> unregisterDevice() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getInt(_deviceIdKey);
    if (deviceId == null) return;
    // Even on failure: the next login re-registers this installation
    await prefs.remove(_deviceIdKey);
    if (AuthService.isLoggedIn) await ApiService.deletePushDevice(deviceId);
  }

  /// Account deletion: the API already removed the device with the account.
  static Future<void> forgetDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
  }
}
