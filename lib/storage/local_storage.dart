import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _keyUserName = 'user_name';
  static const _keyLastName = 'user_last_name';
  static const _keyPhone = 'user_phone';
  static const _keyDni = 'user_dni';
  static const _keyBalance = 'user_balance';
  static const _keyPin = 'user_pin';

  // Nombre
  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  // Apellido
  static Future<void> saveLastName(String lastName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastName, lastName);
  }

  static Future<String?> getLastName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastName);
  }

  // Teléfono
  static Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPhone, phone);
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  // DNI
  static Future<void> saveDni(String dni) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDni, dni);
  }

  static Future<String?> getDni() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDni);
  }

  // PIN (como texto, ej: "1234")
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPin, pin);
  }

  static Future<String?> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPin);
  }

  // Saldo
  static Future<void> saveBalance(double balance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBalance, balance);
  }

  static Future<double> getBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyBalance) ?? 0.0;
  }

  // (Opcional) limpiar todo
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyLastName);
    await prefs.remove(_keyPhone);
    await prefs.remove(_keyDni);
    await prefs.remove(_keyPin);
    await prefs.remove(_keyBalance);
  }
}
