import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  Future<void> saveUserData({
    required String name,
    required String hourlyRate,
    required DateTime startDate,
    required DateTime endDate,
    required bool autoClose,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('hourlyRate', hourlyRate);
    await prefs.setString('startDate', startDate.toIso8601String());
    await prefs.setString('endDate', endDate.toIso8601String());
    await prefs.setBool('autoClose', autoClose);
  }

  Future<Map<String, dynamic>> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('name') ?? '',
      'hourlyRate': prefs.getString('hourlyRate') ?? '',
      'startDate': DateTime.parse(prefs.getString('startDate') ?? DateTime.now().toString()),
      'endDate': DateTime.parse(prefs.getString('endDate') ?? DateTime.now().toString()),
      'autoClose': prefs.getBool('autoClose') ?? false,
    };
  }
}