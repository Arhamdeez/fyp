import 'package:shared_preferences/shared_preferences.dart';

const _kToken = 'momentum_token';

class Session {
  String? token;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
  }

  Future<void> saveToken(String value) async {
    token = value;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, value);
  }

  Future<void> clear() async {
    token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
  }
}
