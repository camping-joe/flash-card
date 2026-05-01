import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _api;
  bool _isLoggedIn = false;
  String _username = '';
  String _baseUrl = 'http://192.168.3.11:8887';

  AuthProvider(this._api);

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get baseUrl => _baseUrl;

  Future<void> init() async {
    await _api.init();
    _isLoggedIn = _api.isAuthenticated;
    notifyListeners();
  }

  Future<void> login(String baseUrl, String username, String password) async {
    await _api.setBaseUrl(baseUrl);
    _baseUrl = baseUrl;
    await _api.login(username, password);
    _isLoggedIn = true;
    _username = username;
    notifyListeners();
  }

  Future<void> register(String baseUrl, String username, String password) async {
    await _api.setBaseUrl(baseUrl);
    _baseUrl = baseUrl;
    await _api.register(username, password);
    _isLoggedIn = true;
    _username = username;
    notifyListeners();
  }

  Future<void> logout() async {
    await _api.clearAuth();
    _isLoggedIn = false;
    _username = '';
    notifyListeners();
  }
}
