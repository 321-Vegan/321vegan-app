import 'package:shared_preferences/shared_preferences.dart';
import '../models/seasonal_theme.dart';
import '../services/subscription_service.dart';
import '../themes/default_theme.dart';
import '../themes/spring_theme.dart';
import '../themes/summer_theme.dart';
import '../themes/autumn_theme.dart';
import '../themes/winter_theme.dart';

class ThemeHelper {
  static const String _themePreferenceKey = 'selected_theme';
  static const String _autoThemeKey = 'auto_theme';

  // Get all available themes, in calendar order so the theme-switcher
  // carousel swipes through the seasons in a natural sequence.
  static List<SeasonalTheme> getAllThemes() {
    return [
      defaultTheme,
      springTheme,
      summerTheme,
      autumnTheme,
      winterTheme,
    ];
  }

  static Season getCurrentSeason() {
    final now = DateTime.now();
    final month = now.month;
    final day = now.day;

    // Spring: March 20 – June 20
    if ((month == 3 && day >= 20) ||
        month == 4 ||
        month == 5 ||
        (month == 6 && day <= 20)) {
      return Season.spring;
    }
    // Summer: June 21 – September 21
    if ((month == 6 && day >= 21) ||
        month == 7 ||
        month == 8 ||
        (month == 9 && day <= 21)) {
      return Season.summer;
    }
    // Autumn: September 22 – December 20
    if ((month == 9 && day >= 22) ||
        month == 10 ||
        month == 11 ||
        (month == 12 && day <= 20)) {
      return Season.autumn;
    }
    // Winter: December 21 – March 19
    return Season.winter;
  }

  static SeasonalTheme getThemeBySeason(Season season) {
    switch (season) {
      case Season.defaultTheme:
        return defaultTheme;
      case Season.spring:
        return springTheme;
      case Season.summer:
        return summerTheme;
      case Season.autumn:
        return autumnTheme;
      case Season.winter:
        return winterTheme;
    }
  }

  static Future<void> saveThemePreference(Season? season) async {
    final prefs = await SharedPreferences.getInstance();
    if (season == null) {
      await prefs.remove(_themePreferenceKey);
    } else {
      await prefs.setString(_themePreferenceKey, season.name);
    }
  }

  static Future<void> saveAutoThemePreference(bool isAuto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoThemeKey, isAuto);
  }

  static Future<bool> isAutoThemeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoThemeKey) ?? false;
  }

  static Future<Season?> getSavedThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final seasonName = prefs.getString(_themePreferenceKey);
    if (seasonName == null) return null;

    try {
      return Season.values.firstWhere((s) => s.name == seasonName);
    } catch (e) {
      return null;
    }
  }

  static Future<SeasonalTheme> getCurrentTheme() async {
    final isSubscribed = SubscriptionService.isSubscribed;
    final isAuto = await isAutoThemeEnabled();

    if (isAuto) {
      // Auto theme requires subscription
      if (!isSubscribed) return defaultTheme;
      final season = getCurrentSeason();
      return getThemeBySeason(season);
    } else {
      final savedSeason = await getSavedThemePreference();
      if (savedSeason != null) {
        final savedTheme = getThemeBySeason(savedSeason);
        if (savedTheme.isPremium && !isSubscribed) {
          return defaultTheme;
        }
        return getThemeBySeason(savedSeason);
      } else {
        return defaultTheme;
      }
    }
  }
}
