import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/flashcard.dart';
import '../models/study_plan.dart';
import '../models/library.dart';

class ApiService {
  String? _baseUrl;
  String? _token;

  String get baseUrl => _baseUrl ?? 'http://192.168.3.11:8887';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('base_url');
    _token = prefs.getString('token');
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> clearAuth() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers {
    final h = {'Content-Type': 'application/json'};
    if (_token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Future<TokenResponse> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['access_token'] != null) {
      final token = TokenResponse.fromJson(data);
      await setToken(token.accessToken);
      return token;
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<TokenResponse> register(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['access_token'] != null) {
      final token = TokenResponse.fromJson(data);
      await setToken(token.accessToken);
      return token;
    }
    throw Exception(data['message'] ?? 'Register failed');
  }

  Future<Map<String, dynamic>> getTodayCards() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/study/today'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Failed to load today cards');
  }

  Future<Map<String, dynamic>> reviewCard(int cardId, int rating) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/flashcards/$cardId/review'),
      headers: _headers,
      body: jsonEncode({'rating': rating}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Review failed');
  }

  Future<List<Flashcard>> getFlashcards({int skip = 0, int limit = 100, int? libraryId}) async {
    var url = '$baseUrl/api/flashcards?skip=$skip&limit=$limit';
    if (libraryId != null) url += '&library_id=$libraryId';
    final res = await http.get(
      Uri.parse(url),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      final items = data['items'] as List;
      return items.map((e) => Flashcard.fromJson(e)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load flashcards');
  }

  Future<StudyPlan> getStudyPlan() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/study/plan'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return StudyPlan.fromJson(data);
    throw Exception(data['message'] ?? 'Failed to load plan');
  }

  Future<StudyPlan> updateStudyPlan(StudyPlan plan) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/study/plan'),
      headers: _headers,
      body: jsonEncode(plan.toJson()),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return StudyPlan.fromJson(data);
    throw Exception(data['message'] ?? 'Failed to update plan');
  }

  Future<StudyStats> getStats() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/study/stats'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return StudyStats.fromJson(data);
    throw Exception(data['message'] ?? 'Failed to load stats');
  }

  Future<Map<String, dynamic>> getAlgorithmSettings() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/admin/algorithm-settings'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Failed to load algorithm settings');
  }

  Future<List<Map<String, dynamic>>> getStudyRecords() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/study/records'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return (data as List).map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load study records');
  }

  Future<Map<String, dynamic>> getDailyTask() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/study/daily-task'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Failed to load daily task');
  }

  Future<Flashcard> createFlashcard(String front, String back, {required int libraryId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/flashcards'),
      headers: _headers,
      body: jsonEncode({
        'front': front,
        'back': back,
        'difficulty': 0,
        'library_id': libraryId,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return Flashcard.fromJson(data);
    throw Exception(data['message'] ?? 'Failed to create flashcard');
  }

  Future<Flashcard> updateFlashcard(int id, String front, String back, {required int libraryId}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/flashcards/$id'),
      headers: _headers,
      body: jsonEncode({
        'front': front,
        'back': back,
        'library_id': libraryId,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return Flashcard.fromJson(data);
    throw Exception(data['message'] ?? 'Failed to update flashcard');
  }

  Future<void> deleteFlashcard(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/flashcards/$id'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to delete flashcard');
    }
  }

  Future<List<Library>> getLibraries({int skip = 0, int limit = 100}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/libraries?skip=$skip&limit=$limit'),
      headers: _headers,
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      final items = data['items'] as List;
      return items.map((e) => Library.fromJson(e)).toList();
    }
    throw Exception(data['message'] ?? 'Failed to load libraries');
  }

  Future<Library> createLibrary(String name, {String? description}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/libraries'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        if (description != null) 'description': description,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return Library.fromJson(data);
    throw Exception(data['message'] ?? 'Failed to create library');
  }

  Future<Library> updateLibrary(int id, String name, {String? description}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/libraries/$id'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        if (description != null) 'description': description,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return Library.fromJson(data);
    throw Exception(data['message'] ?? 'Failed to update library');
  }

  Future<void> deleteLibrary(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/libraries/$id'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['message'] ?? 'Failed to delete library');
    }
  }
}
