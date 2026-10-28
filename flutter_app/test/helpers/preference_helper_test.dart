import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vegan_app/helpers/preference_helper.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesHelper.addSelectedDateToPrefs', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves a real date as ISO8601 string', () async {
      final date = DateTime(2024, 5, 15, 12, 30, 0);
      await PreferencesHelper.addSelectedDateToPrefs(date);
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('selected_date');
      expect(stored, date.toIso8601String());
    });

    test('saves null as "none"', () async {
      await PreferencesHelper.addSelectedDateToPrefs(null);
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('selected_date');
      expect(stored, "none");
    });
  });

  group('PreferencesHelper.getSelectedDateFromPrefs', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns DateTime when a valid ISO8601 string is stored', () async {
      final date = DateTime(2024, 5, 15, 12, 30, 0);
      SharedPreferences.setMockInitialValues({
        'selected_date': date.toIso8601String(),
      });

      final result = await PreferencesHelper.getSelectedDateFromPrefs();
      expect(result, isNotNull);
      expect(result, date);
    });

    test('returns null when "none" is stored', () async {
      SharedPreferences.setMockInitialValues({
        'selected_date': 'none',
      });

      final result = await PreferencesHelper.getSelectedDateFromPrefs();
      expect(result, isNull);
    });
  });

  group('PreferencesHelper.isCodeInPreferences', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns true if code is present', () async {
      SharedPreferences.setMockInitialValues({
        'codes_with_status': '{"abc123": true, "def456": false}',
      });
      final result = await PreferencesHelper.isCodeInPreferences('abc123');
      expect(result, isTrue);
    });

    test('returns false if code is not present', () async {
      SharedPreferences.setMockInitialValues({
        'codes_with_status': '{"abc123": true, "def456": false}',
      });
      final result = await PreferencesHelper.isCodeInPreferences('xyz789');
      expect(result, isFalse);
    });

    test('returns false if nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await PreferencesHelper.isCodeInPreferences('abc123');
      expect(result, isFalse);
    });

    test('returns null when nothing is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await PreferencesHelper.getSelectedDateFromPrefs();
      expect(result, isNull);
    });
  });

  group('PreferencesHelper.addCodeToPreferences', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds a code with success=true', () async {
      await PreferencesHelper.addCodeToPreferences('abc123', true);
      final prefs = await SharedPreferences.getInstance();
      final codesJson = prefs.getString('codes_with_status');
      final codes = Map<String, dynamic>.from(json.decode(codesJson!));
      expect(codes['abc123'], true);
    });

    test('adds a code with success=false', () async {
      await PreferencesHelper.addCodeToPreferences('def456', false);
      final prefs = await SharedPreferences.getInstance();
      final codesJson = prefs.getString('codes_with_status');
      final codes = Map<String, dynamic>.from(json.decode(codesJson!));
      expect(codes['def456'], false);
    });

    test('updates code to true if already false', () async {
      SharedPreferences.setMockInitialValues({
        'codes_with_status': '{"ghi789": false}',
      });
      await PreferencesHelper.addCodeToPreferences('ghi789', true);
      final prefs = await SharedPreferences.getInstance();
      final codesJson = prefs.getString('codes_with_status');
      final codes = Map<String, dynamic>.from(json.decode(codesJson!));
      expect(codes['ghi789'], true);
    });

    test('does not update code to false if already true', () async {
      SharedPreferences.setMockInitialValues({
        'codes_with_status': '{"jkl012": true}',
      });
      await PreferencesHelper.addCodeToPreferences('jkl012', false);
      final prefs = await SharedPreferences.getInstance();
      final codesJson = prefs.getString('codes_with_status');
      final codes = Map<String, dynamic>.from(json.decode(codesJson!));
      expect(codes['jkl012'], true);
    });

    test('does nothing if code is null', () async {
      await PreferencesHelper.addCodeToPreferences(null, true);
      final prefs = await SharedPreferences.getInstance();
      final codesJson = prefs.getString('codes_with_status');
      expect(codesJson, isNull);
    });

    test('keeps only 300 sent codes', () async {
      // Add 301 codes to exceed the limit
      for (int i = 0; i < 301; i++) {
        await PreferencesHelper.addCodeToPreferences('code$i', true);
      }

      final prefs = await SharedPreferences.getInstance();
      final codesJson = prefs.getString('codes_with_status');
      final codes = Map<String, dynamic>.from(json.decode(codesJson!));

      // Should have exactly 300 codes
      expect(codes.length, 300);

      // The oldest code (code0) should be removed
      expect(codes.containsKey('code0'), false);

      // The newest code (code300) should be present
      expect(codes.containsKey('code300'), true);
    });

    test('tracks total successful submissions', () async {
      // Add some successful submissions
      await PreferencesHelper.addCodeToPreferences('code1', true);
      await PreferencesHelper.addCodeToPreferences('code2', true);
      await PreferencesHelper.addCodeToPreferences(
          'code3', false); // This shouldn't count
      await PreferencesHelper.addCodeToPreferences('code4', true);

      final total = await PreferencesHelper.getTotalSuccessfulSubmissions();
      expect(total, 3);
    });

    test('maintains total count even when codes are removed due to limit',
        () async {
      // Add 301 successful codes to exceed the limit
      for (int i = 0; i < 301; i++) {
        await PreferencesHelper.addCodeToPreferences('code$i', true);
      }

      final total = await PreferencesHelper.getTotalSuccessfulSubmissions();
      expect(total,
          301); // Total should still be 301 even though only 300 codes remain

      final prefs = await SharedPreferences.getInstance();
      final codesJson = prefs.getString('codes_with_status');
      final codes = Map<String, dynamic>.from(json.decode(codesJson!));
      expect(codes.length, 300); // But only 300 codes should remain
    });

    test(
        'sets total_successful_submissions to the number of successful submissions',
        () async {
      await PreferencesHelper.addCodeToPreferences('code1', true);
      await PreferencesHelper.addCodeToPreferences('code2', true);
      final prefs = await SharedPreferences.getInstance();
      final total = prefs.getInt('total_successful_submissions');
      expect(total, 2);
    });
  });

  group('PreferencesHelper.getCodesWithStatusFromPreferences', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns a map when codes_with_status is present', () async {
      SharedPreferences.setMockInitialValues({
        'codes_with_status': '{"abc123": true, "def456": false}',
      });

      final result =
          await PreferencesHelper.getCodesWithStatusFromPreferences();
      expect(result, isA<Map<String, bool>>());
      expect(result.length, 2);
      expect(result['abc123'], true);
      expect(result['def456'], false);
    });

    test('returns an empty map when codes_with_status is not present',
        () async {
      SharedPreferences.setMockInitialValues({});
      final result =
          await PreferencesHelper.getCodesWithStatusFromPreferences();
      expect(result, isA<Map<String, bool>>());
      expect(result, isEmpty);
    });
  });

  group('PreferencesHelper.getSuccessfulCodesFromPreferences', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns only codes with value true', () async {
      SharedPreferences.setMockInitialValues({
        'codes_with_status':
            '{"abc123": true, "def456": false, "ghi789": true}',
      });

      final result =
          await PreferencesHelper.getSuccessfulCodesFromPreferences();
      expect(result, isA<List<String>>());
      expect(result.length, 2);
      expect(result, containsAll(['abc123', 'ghi789']));
      expect(result, isNot(contains('def456')));
    });

    test('returns empty list if no codes are successful', () async {
      SharedPreferences.setMockInitialValues({
        'codes_with_status': '{"abc123": false, "def456": false}',
      });

      final result =
          await PreferencesHelper.getSuccessfulCodesFromPreferences();
      expect(result, isA<List<String>>());
      expect(result, isEmpty);
    });

    test('returns empty list if codes_with_status is not present', () async {
      SharedPreferences.setMockInitialValues({});
      final result =
          await PreferencesHelper.getSuccessfulCodesFromPreferences();
      expect(result, isA<List<String>>());
      expect(result, isEmpty);
    });
  });

  group('PreferencesHelper.addBarcodeToHistory', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('adds a new barcode to empty history', () async {
      await PreferencesHelper.addBarcodeToHistory('12345');
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('scan_history');
      expect(historyJson, isNotNull);

      final history =
          List<Map<String, dynamic>>.from(json.decode(historyJson!));
      expect(history.length, 1);
      expect(history.first['barcode'], '12345');
    });

    test('does not add duplicate barcode in the same minute', () async {
      final now = DateTime.now().toIso8601String();
      final initialHistory = [
        {'barcode': '12345', 'timestamp': now}
      ];
      SharedPreferences.setMockInitialValues({
        'scan_history': json.encode(initialHistory),
      });

      await PreferencesHelper.addBarcodeToHistory('12345');
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('scan_history');
      final history =
          List<Map<String, dynamic>>.from(json.decode(historyJson!));
      expect(history.length, 1);
    });

    test('keeps only 300 items in history', () async {
      final now = DateTime.now();
      final initialHistory = List.generate(300, (i) {
        return {
          'barcode': '123$i',
          'timestamp': now.subtract(Duration(minutes: i + 1)).toIso8601String(),
        };
      });
      SharedPreferences.setMockInitialValues({
        'scan_history': json.encode(initialHistory),
      });

      await PreferencesHelper.addBarcodeToHistory('6958591');
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('scan_history');
      final history =
          List<Map<String, dynamic>>.from(json.decode(historyJson!));
      expect(history.length, 300);
      expect(history.last['barcode'], '6958591');
    });
  });

  group('PreferencesHelper.getScanHistory', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns a reversed list of scan history when present', () async {
      final history = [
        {'barcode': '111', 'timestamp': '2024-05-15T10:00:00.000'},
        {'barcode': '222', 'timestamp': '2024-05-15T11:00:00.000'},
      ];
      SharedPreferences.setMockInitialValues({
        'scan_history': json.encode(history),
      });

      final result = await PreferencesHelper.getScanHistory();
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result.length, 2);
      expect(result.first['barcode'], '222'); // reversed order
      expect(result.last['barcode'], '111');
    });

    test('returns an empty list when scan_history is not present', () async {
      SharedPreferences.setMockInitialValues({});
      final result = await PreferencesHelper.getScanHistory();
      expect(result, isA<List<Map<String, dynamic>>>());
      expect(result, isEmpty);
    });
  });

  group('PreferencesHelper.clearScanHistory', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'scan_history': json.encode([
          {'barcode': '111', 'timestamp': '2024-05-15T10:00:00.000'}
        ]),
      });
    });

    test('removes scan_history from SharedPreferences', () async {
      await PreferencesHelper.clearScanHistory();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('scan_history'), isNull);
    });
  });

  group('PreferencesHelper last map layer', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('is null until a layer was chosen', () async {
      expect(await PreferencesHelper.getLastMapLayerPref(), isNull);
    });

    test('returns the last chosen layer', () async {
      await PreferencesHelper.setLastMapLayerPref('restaurants');
      expect(await PreferencesHelper.getLastMapLayerPref(), 'restaurants');
      await PreferencesHelper.setLastMapLayerPref('shops');
      expect(await PreferencesHelper.getLastMapLayerPref(), 'shops');
    });
  });
}
