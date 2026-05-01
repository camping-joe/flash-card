import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/flashcard.dart';
import '../models/library.dart';
import '../models/study_plan.dart';

class DbService {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'flashcard.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
        await _createAlgorithmSettingsTable(db);
        await _createDailyTasksTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createAlgorithmSettingsTable(db);
        }
        if (oldVersion < 3) {
          await _createDailyTasksTable(db);
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE libraries ADD COLUMN daily_new_cards INTEGER');
          await db.execute('ALTER TABLE libraries ADD COLUMN daily_review_limit INTEGER');
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE libraries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        daily_new_cards INTEGER,
        daily_review_limit INTEGER,
        created_at TEXT,
        updated_at TEXT,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');
    await db.execute('''
      CREATE TABLE flashcards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        front TEXT NOT NULL,
        back TEXT NOT NULL,
        library_id INTEGER NOT NULL,
        difficulty INTEGER DEFAULT 0,
        created_at TEXT,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');
    await db.execute('''
      CREATE TABLE study_records (
        flashcard_id INTEGER PRIMARY KEY,
        interval_days INTEGER DEFAULT 0,
        ease_factor REAL DEFAULT 2.5,
        repetitions INTEGER DEFAULT 0,
        next_review_at TEXT,
        last_review_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE study_plan (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        daily_new_cards INTEGER DEFAULT 20,
        daily_review_limit INTEGER DEFAULT 100,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');
    await db.execute('''
      CREATE TABLE pending_reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        flashcard_id INTEGER NOT NULL,
        server_flashcard_id INTEGER,
        rating INTEGER NOT NULL,
        reviewed_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  Future<void> _createAlgorithmSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS algorithm_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        new_card_easy_interval INTEGER DEFAULT 3,
        new_card_hard_interval INTEGER DEFAULT 1,
        second_repetition_interval INTEGER DEFAULT 6,
        min_ease_factor REAL DEFAULT 1.3,
        initial_ease_factor REAL DEFAULT 2.5
      )
    ''');
  }

  // ========== Libraries ==========
  Future<List<Library>> getLibraries() async {
    final db = await database;
    final rows = await db.query('libraries', where: "sync_status != 'pending_delete'");
    return rows.map((r) => _libraryFromRow(r)).toList();
  }

  Future<void> upsertLibrary(Map<String, dynamic> data) async {
    final db = await database;
    final existing = await db.query('libraries', where: 'server_id = ?', whereArgs: [data['server_id']]);
    if (existing.isEmpty) {
      await db.insert('libraries', data);
    } else {
      await db.update('libraries', data, where: 'server_id = ?', whereArgs: [data['server_id']]);
    }
  }

  Future<int> insertLocalLibrary(String name, {String? description}) async {
    final db = await database;
    return await db.insert('libraries', {
      'name': name,
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending_create',
    });
  }

  Future<void> updateLocalLibrary(int localId, String name, {String? description}) async {
    final db = await database;
    await db.update('libraries', {
      'name': name,
      'description': description,
      'updated_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending_update',
    }, where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> markLibraryDeleted(int localId) async {
    final db = await database;
    await db.update('libraries', {'sync_status': 'pending_delete'}, where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> deleteLibraryPermanently(int localId) async {
    final db = await database;
    await db.delete('libraries', where: 'id = ?', whereArgs: [localId]);
  }

  // ========== Flashcards ==========
  Future<List<Map<String, dynamic>>> getFlashcards({int? libraryId}) async {
    final db = await database;
    String where = "sync_status != 'pending_delete'";
    List<Object?>? args;
    if (libraryId != null) {
      where += ' AND library_id = ?';
      args = [libraryId];
    }
    final rows = await db.query('flashcards', where: where, whereArgs: args, orderBy: 'id DESC');
    return rows;
  }

  Future<Map<String, dynamic>?> getFlashcard(int localId) async {
    final db = await database;
    final rows = await db.query('flashcards', where: 'id = ?', whereArgs: [localId]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>?> getFlashcardByServerId(int serverId) async {
    final db = await database;
    final rows = await db.query('flashcards', where: 'server_id = ?', whereArgs: [serverId]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertFlashcard(Map<String, dynamic> data) async {
    final db = await database;
    final existing = await db.query('flashcards', where: 'server_id = ?', whereArgs: [data['server_id']]);
    if (existing.isEmpty) {
      await db.insert('flashcards', data);
    } else {
      await db.update('flashcards', data, where: 'server_id = ?', whereArgs: [data['server_id']]);
    }
  }

  Future<int> insertLocalFlashcard(String front, String back, int libraryId) async {
    final db = await database;
    return await db.insert('flashcards', {
      'front': front,
      'back': back,
      'library_id': libraryId,
      'difficulty': 0,
      'created_at': DateTime.now().toIso8601String(),
      'sync_status': 'pending_create',
    });
  }

  Future<void> updateLocalFlashcard(int localId, String front, String back, int libraryId) async {
    final db = await database;
    await db.update('flashcards', {
      'front': front,
      'back': back,
      'library_id': libraryId,
      'sync_status': 'pending_update',
    }, where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> markFlashcardDeleted(int localId) async {
    final db = await database;
    await db.update('flashcards', {'sync_status': 'pending_delete'}, where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> deleteFlashcardPermanently(int localId) async {
    final db = await database;
    await db.delete('flashcards', where: 'id = ?', whereArgs: [localId]);
    await db.delete('study_records', where: 'flashcard_id = ?', whereArgs: [localId]);
  }

  Future<void> updateFlashcardServerId(int localId, int serverId) async {
    final db = await database;
    await db.update('flashcards', {'server_id': serverId, 'sync_status': 'synced'}, where: 'id = ?', whereArgs: [localId]);
  }

  // ========== Study Records ==========
  Future<Map<String, dynamic>?> getStudyRecord(int flashcardId) async {
    final db = await database;
    final rows = await db.query('study_records', where: 'flashcard_id = ?', whereArgs: [flashcardId]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> upsertStudyRecord(int flashcardId, Map<String, dynamic> data) async {
    final db = await database;
    final existing = await db.query('study_records', where: 'flashcard_id = ?', whereArgs: [flashcardId]);
    if (existing.isEmpty) {
      await db.insert('study_records', {'flashcard_id': flashcardId, ...data});
    } else {
      await db.update('study_records', data, where: 'flashcard_id = ?', whereArgs: [flashcardId]);
    }
  }

  Future<void> upsertStudyRecordByServerId(int serverFlashcardId, Map<String, dynamic> data) async {
    final db = await database;
    final rows = await db.query('flashcards', where: 'server_id = ?', whereArgs: [serverFlashcardId]);
    if (rows.isEmpty) return;
    final localId = rows.first['id'] as int;
    final existing = await db.query('study_records', where: 'flashcard_id = ?', whereArgs: [localId]);
    final recordData = {
      'interval_days': data['interval_days'] ?? 0,
      'ease_factor': data['ease_factor'] ?? 2.5,
      'repetitions': data['repetitions'] ?? 0,
      'next_review_at': data['next_review_at'],
      'last_review_at': data['last_review_at'],
    };
    if (existing.isEmpty) {
      await db.insert('study_records', {'flashcard_id': localId, ...recordData});
    } else {
      await db.update('study_records', recordData, where: 'flashcard_id = ?', whereArgs: [localId]);
    }
  }

  // ========== Study Plan ==========
  Future<StudyPlan?> getStudyPlan() async {
    final db = await database;
    final rows = await db.query('study_plan');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return StudyPlan(
      id: 1,
      userId: 0,
      name: 'default',
      dailyNewCards: r['daily_new_cards'] as int,
      dailyReviewLimit: r['daily_review_limit'] as int,
    );
  }

  Future<void> saveStudyPlan(StudyPlan plan) async {
    final db = await database;
    final existing = await db.query('study_plan');
    final data = {
      'id': 1,
      'daily_new_cards': plan.dailyNewCards,
      'daily_review_limit': plan.dailyReviewLimit,
      'sync_status': 'pending_update',
    };
    if (existing.isEmpty) {
      await db.insert('study_plan', data);
    } else {
      await db.update('study_plan', data);
    }
  }

  // ========== Algorithm Settings ==========
  Future<Map<String, dynamic>> getAlgorithmSettings() async {
    final db = await database;
    await _createAlgorithmSettingsTable(db);
    final rows = await db.query('algorithm_settings');
    if (rows.isEmpty) {
      final defaults = {
        'id': 1,
        'new_card_easy_interval': 3,
        'new_card_hard_interval': 1,
        'second_repetition_interval': 6,
        'min_ease_factor': 1.3,
        'initial_ease_factor': 2.5,
      };
      await db.insert('algorithm_settings', defaults);
      return defaults;
    }
    return rows.first;
  }

  Future<void> saveAlgorithmSettings(Map<String, dynamic> data) async {
    final db = await database;
    await _createAlgorithmSettingsTable(db);
    final existing = await db.query('algorithm_settings');
    final values = {
      'id': 1,
      ...data,
    };
    if (existing.isEmpty) {
      await db.insert('algorithm_settings', values);
    } else {
      await db.update('algorithm_settings', values);
    }
  }

  Future<void> _createDailyTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_tasks (
        date TEXT PRIMARY KEY,
        new_cards_done INTEGER DEFAULT 0,
        review_done INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'synced'
      )
    ''');
  }

  Future<Map<String, dynamic>> getDailyTask(String date) async {
    final db = await database;
    await _createDailyTasksTable(db);
    final rows = await db.query('daily_tasks', where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) {
      return {
        'date': date,
        'new_cards_done': 0,
        'review_done': 0,
      };
    }
    return rows.first;
  }

  Future<void> incrementDailyNewCards(String date) async {
    final db = await database;
    await _createDailyTasksTable(db);
    final existing = await db.query('daily_tasks', where: 'date = ?', whereArgs: [date]);
    if (existing.isEmpty) {
      await db.insert('daily_tasks', {
        'date': date,
        'new_cards_done': 1,
        'review_done': 0,
        'sync_status': 'pending_update',
      });
    } else {
      await db.update('daily_tasks', {
        'new_cards_done': (existing.first['new_cards_done'] as int) + 1,
        'sync_status': 'pending_update',
      }, where: 'date = ?', whereArgs: [date]);
    }
  }

  Future<void> incrementDailyReviews(String date) async {
    final db = await database;
    await _createDailyTasksTable(db);
    final existing = await db.query('daily_tasks', where: 'date = ?', whereArgs: [date]);
    if (existing.isEmpty) {
      await db.insert('daily_tasks', {
        'date': date,
        'new_cards_done': 0,
        'review_done': 1,
        'sync_status': 'pending_update',
      });
    } else {
      await db.update('daily_tasks', {
        'review_done': (existing.first['review_done'] as int) + 1,
        'sync_status': 'pending_update',
      }, where: 'date = ?', whereArgs: [date]);
    }
  }

  Future<void> saveDailyTask(Map<String, dynamic> data) async {
    final db = await database;
    await _createDailyTasksTable(db);
    final existing = await db.query('daily_tasks', where: 'date = ?', whereArgs: [data['date']]);
    if (existing.isEmpty) {
      await db.insert('daily_tasks', data);
    } else {
      await db.update('daily_tasks', data, where: 'date = ?', whereArgs: [data['date']]);
    }
  }

  // ========== Pending Reviews ==========
  Future<void> addPendingReview(int flashcardId, int? serverFlashcardId, int rating) async {
    final db = await database;
    await db.insert('pending_reviews', {
      'flashcard_id': flashcardId,
      'server_flashcard_id': serverFlashcardId,
      'rating': rating,
      'reviewed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingReviews() async {
    final db = await database;
    return await db.query('pending_reviews');
  }

  Future<void> clearPendingReviews() async {
    final db = await database;
    await db.delete('pending_reviews');
  }

  Future<void> removePendingReview(int id) async {
    final db = await database;
    await db.delete('pending_reviews', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Sync Helpers ==========
  Future<List<Map<String, dynamic>>> getPendingCreates(String table) async {
    final db = await database;
    return await db.query(table, where: "sync_status = 'pending_create'");
  }

  Future<List<Map<String, dynamic>>> getPendingUpdates(String table) async {
    final db = await database;
    return await db.query(table, where: "sync_status = 'pending_update'");
  }

  Future<List<Map<String, dynamic>>> getPendingDeletes(String table) async {
    final db = await database;
    return await db.query(table, where: "sync_status = 'pending_delete'");
  }

  Future<void> markSynced(String table, int localId) async {
    final db = await database;
    await db.update(table, {'sync_status': 'synced'}, where: 'id = ?', whereArgs: [localId]);
  }

  Future<void> setLastSync(String key, String value) async {
    final db = await database;
    final existing = await db.query('sync_metadata', where: 'key = ?', whereArgs: [key]);
    if (existing.isEmpty) {
      await db.insert('sync_metadata', {'key': key, 'value': value});
    } else {
      await db.update('sync_metadata', {'value': value}, where: 'key = ?', whereArgs: [key]);
    }
  }

  Future<String?> getLastSync(String key) async {
    final db = await database;
    final rows = await db.query('sync_metadata', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  // ========== Today Cards ==========
  Future<List<Map<String, dynamic>>> getTodayCards({int dailyNew = 20, int dailyReview = 100, int remainingNew = 20, int? libraryId}) async {
    final db = await database;
    // 加 1 分钟缓冲，避免重来卡片因微秒级时间差而暂时消失
    final now = DateTime.now().add(const Duration(minutes: 1));
    final nowStr = now.toIso8601String();

    final libFilter = libraryId != null ? 'AND f.library_id = $libraryId' : '';

    // 复习卡：next_review_at 已到期且 interval_days > 0（排除重来卡片）
    final reviewRows = await db.rawQuery('''
      SELECT f.*, sr.interval_days, sr.ease_factor, sr.repetitions, sr.next_review_at
      FROM flashcards f
      JOIN study_records sr ON f.id = sr.flashcard_id
      WHERE f.sync_status != 'pending_delete'
        AND sr.next_review_at IS NOT NULL
        AND sr.next_review_at <= ?
        AND sr.interval_days > 0
        $libFilter
      ORDER BY sr.next_review_at ASC
      LIMIT ?
    ''', [nowStr, dailyReview]);

    // 新卡 + 重来卡片：repetitions == 0 且（从未学习过 或 interval_days == 0）
    final newRows = remainingNew > 0
        ? await db.rawQuery('''
          SELECT f.*,
            COALESCE(sr.interval_days, 0) as interval_days,
            COALESCE(sr.ease_factor, 2.5) as ease_factor,
            COALESCE(sr.repetitions, 0) as repetitions,
            sr.next_review_at
          FROM flashcards f
          LEFT JOIN study_records sr ON f.id = sr.flashcard_id
          WHERE f.sync_status != 'pending_delete'
            AND (sr.repetitions IS NULL OR (sr.repetitions = 0 AND (sr.next_review_at IS NULL OR sr.interval_days = 0)))
            $libFilter
          ORDER BY f.id ASC
          LIMIT ?
        ''', [remainingNew])
        : [];

    return [...reviewRows, ...newRows];
  }

  // ========== Stats ==========
  Future<Map<String, dynamic>> getStats() async {
    final db = await database;
    final total = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM flashcards WHERE sync_status != 'pending_delete'")) ?? 0;
    final mastered = Sqflite.firstIntValue(await db.rawQuery("SELECT COUNT(*) FROM study_records WHERE repetitions >= 5")) ?? 0;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
    final reviewsToday = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM pending_reviews WHERE reviewed_at BETWEEN ? AND ?",
      [todayStart, todayEnd],
    )) ?? 0;
    return {
      'total_flashcards': total,
      'mastered_flashcards': mastered,
      'reviews_today': reviewsToday,
      'streak_days': 0,
      'weekly_reviews': [0, 0, 0, 0, 0, 0, 0],
    };
  }

  // ========== Helpers ==========
  Library _libraryFromRow(Map<String, dynamic> r) {
    return Library(
      id: r['id'] as int,
      name: r['name'] as String,
      description: r['description'] as String?,
      dailyNewCards: r['daily_new_cards'] as int?,
      dailyReviewLimit: r['daily_review_limit'] as int?,
      createdAt: r['created_at'] ?? '',
      updatedAt: r['updated_at'] ?? '',
    );
  }
}
