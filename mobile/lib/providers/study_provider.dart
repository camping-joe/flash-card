import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/sm2_service.dart';
import '../services/sync_service.dart';
import '../models/flashcard.dart';
import '../models/study_plan.dart';
import '../models/library.dart';
import '../services/sm2_service.dart' show AlgorithmSettings;

class StudyProvider with ChangeNotifier {
  final ApiService _api;
  final DbService _db;
  late final SyncService _sync;

  List<TodayCard> _todayCards = [];
  int _reviewCount = 0;
  int _newCount = 0;
  int _newCardsToday = 0;
  int _reviewsToday = 0;
  StudyPlan? _plan;
  StudyStats? _stats;
  List<Flashcard> _flashcards = [];
  List<Library> _libraries = [];
  bool _loading = false;
  bool _isOffline = false;
  String? _lastSyncTime;
  AlgorithmSettings _algorithmSettings = AlgorithmSettings();

  StudyProvider(this._api) : _db = DbService() {
    _sync = SyncService(_db, _api);
  }

  List<TodayCard> get todayCards => _todayCards;
  int get reviewCount => _reviewCount;
  int get newCount => _newCount;
  StudyPlan? get plan => _plan;
  StudyStats? get stats => _stats;
  List<Flashcard> get flashcards => _flashcards;
  List<Library> get libraries => _libraries;
  bool get loading => _loading;
  bool get isOffline => _isOffline;
  String? get lastSyncTime => _lastSyncTime;
  AlgorithmSettings get algorithmSettings => _algorithmSettings;
  int get newCardsToday => _newCardsToday;
  int get reviewsToday => _reviewsToday;

  Future<void> init() async {
    await _db.database;
    _lastSyncTime = await _db.getLastSync('full_sync');
    await loadPlan();
    await loadAlgorithmSettings();
    await loadLibraries();
    await loadToday();
  }

  Future<void> loadAlgorithmSettings() async {
    try {
      final settings = await _db.getAlgorithmSettings();
      _algorithmSettings = AlgorithmSettings(
        newCardEasyInterval: settings['new_card_easy_interval'] as int? ?? 3,
        newCardHardInterval: settings['new_card_hard_interval'] as int? ?? 1,
        secondRepetitionInterval: settings['second_repetition_interval'] as int? ?? 6,
        minEaseFactor: (settings['min_ease_factor'] as num?)?.toDouble() ?? 1.3,
      );
    } catch (_) {
      _algorithmSettings = AlgorithmSettings();
    }
  }

  Future<SyncResult> sync() async {
    _loading = true;
    notifyListeners();
    try {
      final result = await _sync.sync();
      _isOffline = !result.success;
      _lastSyncTime = await _db.getLastSync('full_sync');
      await loadAlgorithmSettings();
      await loadLibraries();
      await loadToday();
      await loadFlashcards();
      return result;
    } catch (e) {
      _isOffline = true;
      return SyncResult()..errors.add('同步失败: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadToday() async {
    _loading = true;
    notifyListeners();
    try {
      const defaultDailyNew = 20;
      const defaultDailyReview = 100;

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final dailyTask = await _db.getDailyTask(todayStr);
      _newCardsToday = dailyTask['new_cards_done'] as int? ?? 0;
      _reviewsToday = dailyTask['review_done'] as int? ?? 0;

      final libraries = await _db.getLibraries();
      List<Map<String, dynamic>> allRows = [];

      if (libraries.isEmpty) {
        final rows = await _db.getTodayCards(
          dailyNew: defaultDailyNew,
          dailyReview: defaultDailyReview,
          remainingNew: defaultDailyNew,
        );
        allRows.addAll(rows);
      } else {
        for (final lib in libraries) {
          final libNewLimit = lib.dailyNewCards ?? defaultDailyNew;
          final libReviewLimit = lib.dailyReviewLimit ?? defaultDailyReview;
          final rows = await _db.getTodayCards(
            dailyNew: libNewLimit,
            dailyReview: libReviewLimit,
            remainingNew: libNewLimit,
            libraryId: lib.id,
          );
          allRows.addAll(rows);
        }
      }

      _todayCards = allRows.map((r) => TodayCard(
        flashcardId: r['id'] as int,
        front: r['front'] as String,
        back: r['back'] as String,
        isNew: (r['repetitions'] ?? 0) == 0 && (r['next_review_at'] == null || (r['interval_days'] ?? 0) == 0),
        repetitions: r['repetitions'] ?? 0,
        easeFactor: (r['ease_factor'] ?? 2.5).toDouble(),
        intervalDays: r['interval_days'] ?? 0,
      )).toList();

      _reviewCount = _todayCards.where((c) => !c.isNew).length;
      _newCount = _todayCards.where((c) => c.isNew).length;
    } catch (e) {
      _isOffline = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> reviewCard(int cardId, int rating) async {
    final cardRow = await _db.getFlashcard(cardId);
    if (cardRow == null) throw Exception('Card not found');

    final record = await _db.getStudyRecord(cardId);
    final repetitions = record?['repetitions'] ?? 0;
    final easeFactor = (record?['ease_factor'] ?? 2.5).toDouble();
    final interval = record?['interval_days'] ?? 0;

    final result = Sm2Service.calculate(repetitions, easeFactor, interval, rating, settings: _algorithmSettings);

    await _db.upsertStudyRecord(cardId, {
      'interval_days': result.interval,
      'ease_factor': result.easeFactor,
      'repetitions': result.repetitions,
      'next_review_at': result.nextReviewAt.toIso8601String(),
      'last_review_at': DateTime.now().toIso8601String(),
    });

    await _db.addPendingReview(cardId, cardRow['server_id'] as int?, rating);

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    // rating=1 重来不计入任何统计
    if (rating != 1) {
      if (repetitions == 0) {
        await _db.incrementDailyNewCards(todayStr);
        _newCardsToday += 1;
      } else {
        await _db.incrementDailyReviews(todayStr);
        _reviewsToday += 1;
      }
    }

    _todayCards.removeWhere((c) => c.flashcardId == cardId);
    _reviewCount = _todayCards.where((c) => !c.isNew).length;
    _newCount = _todayCards.where((c) => c.isNew).length;
    notifyListeners();
  }

  Future<void> loadFlashcards({int? libraryId}) async {
    _loading = true;
    notifyListeners();
    final rows = await _db.getFlashcards(libraryId: libraryId);
    _flashcards = rows.map((r) => Flashcard(
      id: r['id'] as int,
      front: r['front'] as String,
      back: r['back'] as String,
      libraryId: r['library_id'] as int,
      difficulty: r['difficulty'] as int,
      createdAt: r['created_at'] as String? ?? '',
    )).toList();
    _loading = false;
    notifyListeners();
  }

  Future<void> createFlashcard(String front, String back, {required int libraryId}) async {
    final localId = await _db.insertLocalFlashcard(front, back, libraryId);
    await loadFlashcards();
  }

  Future<void> updateFlashcard(int id, String front, String back, {required int libraryId}) async {
    await _db.updateLocalFlashcard(id, front, back, libraryId);
    await loadFlashcards();
  }

  Future<void> deleteFlashcard(int id) async {
    await _db.markFlashcardDeleted(id);
    await loadFlashcards();
  }

  Future<void> loadLibraries() async {
    _libraries = await _db.getLibraries();
    notifyListeners();
  }

  Future<void> createLibrary(String name, {String? description}) async {
    await _db.insertLocalLibrary(name, description: description);
    await loadLibraries();
  }

  Future<void> updateLibrary(int id, String name, {String? description}) async {
    await _db.updateLocalLibrary(id, name, description: description);
    await loadLibraries();
  }

  Future<void> deleteLibrary(int id) async {
    await _db.markLibraryDeleted(id);
    await loadLibraries();
  }

  Future<void> loadPlan() async {
    _plan = await _db.getStudyPlan();
    if (_plan == null) {
      _plan = StudyPlan(id: 1, userId: 0, name: 'default', dailyNewCards: 20, dailyReviewLimit: 100);
      await _db.saveStudyPlan(_plan!);
    }
    notifyListeners();
  }

  Future<void> updatePlan(StudyPlan plan) async {
    await _db.saveStudyPlan(plan);
    _plan = plan;
    notifyListeners();
  }

  Future<void> loadStats() async {
    final data = await _db.getStats();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final dailyTask = await _db.getDailyTask(todayStr);
    _stats = StudyStats(
      totalFlashcards: data['total_flashcards'],
      masteredFlashcards: data['mastered_flashcards'],
      reviewsToday: dailyTask['review_done'] as int? ?? 0,
      newCardsToday: dailyTask['new_cards_done'] as int? ?? 0,
      streakDays: data['streak_days'],
      weeklyReviews: List<int>.from(data['weekly_reviews']),
    );
    notifyListeners();
  }
}
