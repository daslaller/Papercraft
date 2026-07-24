import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AppUser {
  final String id;
  final String email;
  final String fullName;

  const AppUser({required this.id, required this.email, required this.fullName});

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'fullName': fullName};

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        fullName: j['fullName'] as String? ?? '',
      );
}

class AuthService extends ChangeNotifier {
  AppUser? _user;
  bool _loading = true;

  AppUser? get user => _user;
  bool get loading => _loading;
  bool get isAuthenticated => _user != null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      _user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> login(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('users') ?? '[]';
    final users = (jsonDecode(usersJson) as List).cast<Map<String, dynamic>>();

    final match = users.where((u) =>
        u['email'] == email && u['password'] == password).firstOrNull;

    if (match == null) return 'Invalid email or password';

    _user = AppUser.fromJson(match);
    await prefs.setString('current_user', jsonEncode(_user!.toJson()));
    notifyListeners();
    return null;
  }

  Future<String?> register(String email, String password, String fullName) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString('users') ?? '[]';
    final users = (jsonDecode(usersJson) as List).cast<Map<String, dynamic>>();

    if (users.any((u) => u['email'] == email)) {
      return 'Email already in use';
    }

    final id = const Uuid().v4();
    final newUser = {
      'id': id,
      'email': email,
      'password': password,
      'fullName': fullName,
    };
    users.add(newUser);
    await prefs.setString('users', jsonEncode(users));

    _user = AppUser(id: id, email: email, fullName: fullName);
    await prefs.setString('current_user', jsonEncode(_user!.toJson()));
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    _user = null;
    notifyListeners();
  }
}
