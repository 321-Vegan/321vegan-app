import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:vegan_app/helpers/database_helper.dart';
import 'package:vegan_app/widgets/shared/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:vegan_app/models/b12_reminder_settings.dart';
import 'helpers/first_time_launch.dart';
import 'helpers/preference_helper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'services/b12_reminder_service.dart';
import 'services/notification_service.dart';
import 'services/anniversary_service.dart';
import 'services/products_of_interest_cache.dart';
import 'services/subscription_service.dart';
import 'helpers/theme_helper.dart';

/// Global navigator key for showing dialogs from notification handlers
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {

  WidgetsFlutterBinding.ensureInitialized();
  // Draw behind both system bars on every Android version (Android 15+
  // already enforces this; the explicit call aligns older versions).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await dotenv.load(fileName: ".env");
  await DatabaseHelper.instance.database;
  await DatabaseHelper.instance.cosmeticsDatabase;
  await AuthService.init();
  await PreferencesHelper.rollRandomAvatarIfEnabled();
  await SubscriptionService.init();
  await NotificationService().initialize();
  await _migrateBiweeklyReminderIfNeeded();

  // Keep the yearly vegan anniversary notification scheduled (silent: never
  // prompts for permission : only reschedules if already granted).
  await AnniversaryService.rescheduleIfNeeded();

  // Pre-load products of interest cache at app startup (when likely to have internet)
  ProductsOfInterestCache.initializeAtStartup();

  runApp(const MyApp());
}

/// One-time migration: cancel the old daily-repeating biweekly notification
/// (scheduled with matchDateTimeComponents: time) and replace it with a
/// correct one-shot notification.
Future<void> _migrateBiweeklyReminderIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('biweekly_migration_v1') == true) return;

  final settings = await B12ReminderService.getSettings();
  if (settings.enabled && settings.frequency == ReminderFrequency.biweekly) {
    await B12ReminderService.scheduleReminder(settings);
  }

  await prefs.setBool('biweekly_migration_v1', true);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<MyAppState>();
  }

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  ThemeData _currentTheme = ThemeData(
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF15866E)),
    useMaterial3: true,
    fontFamily: 'Karla',
  );

  late final Upgrader _upgrader;

  @override
  void initState() {
    super.initState();
    const appcastURL =
        'https://raw.githubusercontent.com/llambrecht/321vegan_appcast/main/appcast.xml';
    _upgrader = Upgrader(
      storeController: UpgraderStoreController(
        onAndroid: () => UpgraderAppcastStore(appcastURL: appcastURL),
        oniOS: () => UpgraderAppcastStore(appcastURL: appcastURL),
      ),
    );
    _updateSystemOverlayStyle();
    _loadTheme();
    // Premium entitlement (bypass / backend status / restored receipt) can
    // resolve after startup. When it does, re-evaluate the seasonal theme so
    // a premium theme provisionally shown as the default now applies — and
    // vice-versa on a confirmed downgrade.
    SubscriptionService.revision.addListener(_loadTheme);
  }

  @override
  void dispose() {
    SubscriptionService.revision.removeListener(_loadTheme);
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final seasonalTheme = await ThemeHelper.getCurrentTheme();
    if (!mounted) return;
    setState(() {
      _currentTheme = seasonalTheme.toThemeData();
    });
  }

  Future<void> updateTheme() async {
    await _loadTheme();
  }

  /// Fully transparent system bars (app content shows through) with dark
  /// icons, and the Android 15 contrast scrims disabled.
  static const SystemUiOverlayStyle _overlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light, // iOS: dark status bar text
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  void _updateSystemOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1170, 2532),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.0)),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: '321 Vegan',
          debugShowCheckedModeBanner: false,
          theme: _currentTheme,
          home: CustomUpgradeAlert(
            upgrader: _upgrader,
            child: const FirstLaunchChecker(),
          ),
          // Pages with an AppBar plant their own region with only status-bar
          // fields, which drops our nav-bar styling on the next focus change;
          // this app-wide region re-asserts it every frame.
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: _overlayStyle,
            child: child!,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('fr', 'FR'),
          ],
        ),
      ),
    );
  }
}
