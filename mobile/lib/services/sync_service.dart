import 'db_service.dart';
import 'api_service.dart';
import '../models/study_plan.dart';

class SyncService {
  final DbService _db;
  final ApiService _api;

  SyncService(this._db, this._api);

  Future<SyncResult> sync() async {
    final result = SyncResult();

    try {
      // ========== PUSH ==========

      // 1. Libraries
      final libCreates = await _db.getPendingCreates('libraries');
      for (final row in libCreates) {
        try {
          final lib = await _api.createLibrary(row['name'], description: row['description']);
          await _db.upsertLibrary({
            'server_id': lib.id,
            'name': lib.name,
            'description': lib.description,
            'daily_new_cards': lib.dailyNewCards,
            'daily_review_limit': lib.dailyReviewLimit,
            'created_at': lib.createdAt,
            'updated_at': lib.updatedAt,
            'sync_status': 'synced',
          });
          await _db.deleteLibraryPermanently(row['id'] as int);
          result.createdLibraries++;
        } catch (e) {
          result.errors.add('创建卡库失败: $e');
        }
      }

      final libUpdates = await _db.getPendingUpdates('libraries');
      for (final row in libUpdates) {
        if (row['server_id'] == null) continue;
        try {
          await _api.updateLibrary(row['server_id'] as int, row['name'], description: row['description']);
          await _db.markSynced('libraries', row['id'] as int);
          result.updatedLibraries++;
        } catch (e) {
          result.errors.add('更新卡库失败: $e');
        }
      }

      final libDeletes = await _db.getPendingDeletes('libraries');
      for (final row in libDeletes) {
        if (row['server_id'] == null) continue;
        try {
          await _api.deleteLibrary(row['server_id'] as int);
          await _db.deleteLibraryPermanently(row['id'] as int);
          result.deletedLibraries++;
        } catch (e) {
          result.errors.add('删除卡库失败: $e');
        }
      }

      // 2. Flashcards
      final cardCreates = await _db.getPendingCreates('flashcards');
      for (final row in cardCreates) {
        try {
          // Map local library_id to server library_id
          final libRow = await _db.database.then((db) =>
            db.query('libraries', where: 'id = ?', whereArgs: [row['library_id']]));
          int? serverLibId;
          if (libRow.isNotEmpty) {
            serverLibId = libRow.first['server_id'] as int? ?? libRow.first['id'] as int;
          }
          if (serverLibId == null) {
            result.errors.add('卡片 ${row['front']} 的卡库未同步');
            continue;
          }
          final card = await _api.createFlashcard(row['front'], row['back'], libraryId: serverLibId);
          await _db.updateFlashcardServerId(row['id'] as int, card.id);
          result.createdFlashcards++;
        } catch (e) {
          result.errors.add('创建卡片失败: $e');
        }
      }

      final cardUpdates = await _db.getPendingUpdates('flashcards');
      for (final row in cardUpdates) {
        if (row['server_id'] == null) continue;
        try {
          final libRow = await _db.database.then((db) =>
            db.query('libraries', where: 'id = ?', whereArgs: [row['library_id']]));
          int? serverLibId;
          if (libRow.isNotEmpty) {
            serverLibId = libRow.first['server_id'] as int? ?? libRow.first['id'] as int;
          }
          await _api.updateFlashcard(row['server_id'] as int, row['front'], row['back'], libraryId: serverLibId ?? row['library_id'] as int);
          await _db.markSynced('flashcards', row['id'] as int);
          result.updatedFlashcards++;
        } catch (e) {
          result.errors.add('更新卡片失败: $e');
        }
      }

      final cardDeletes = await _db.getPendingDeletes('flashcards');
      for (final row in cardDeletes) {
        if (row['server_id'] == null) continue;
        try {
          await _api.deleteFlashcard(row['server_id'] as int);
          await _db.deleteFlashcardPermanently(row['id'] as int);
          result.deletedFlashcards++;
        } catch (e) {
          result.errors.add('删除卡片失败: $e');
        }
      }

      // 3. Pending reviews
      final pendingReviews = await _db.getPendingReviews();
      for (final row in pendingReviews) {
        int? serverCardId = row['server_flashcard_id'] as int?;
        if (serverCardId == null) {
          final cardRow = await _db.getFlashcard(row['flashcard_id'] as int);
          serverCardId = cardRow?['server_id'] as int?;
        }
        if (serverCardId == null) {
          result.errors.add('复习记录对应的卡片未同步');
          continue;
        }
        try {
          await _api.reviewCard(serverCardId, row['rating'] as int);
          await _db.removePendingReview(row['id'] as int);
          result.syncedReviews++;
        } catch (e) {
          result.errors.add('同步复习记录失败: $e');
        }
      }

      // 4. Study plan
      final planRows = await _db.database.then((db) =>
        db.query('study_plan', where: "sync_status = 'pending_update'"));
      if (planRows.isNotEmpty) {
        try {
          final r = planRows.first;
          await _api.updateStudyPlan(StudyPlan(
            id: 1, userId: 0, name: 'default',
            dailyNewCards: r['daily_new_cards'] as int,
            dailyReviewLimit: r['daily_review_limit'] as int,
          ));
          await _db.database.then((db) =>
            db.update('study_plan', {'sync_status': 'synced'}));
        } catch (e) {
          result.errors.add('同步学习计划失败: $e');
        }
      }

      // ========== PULL ==========
      await _pullLibraries();
      await _pullFlashcards();
      await _pullStudyRecords();
      await _pullStudyPlan();
      await _pullAlgorithmSettings();
      await _pullDailyTask();

      await _db.setLastSync('full_sync', DateTime.now().toIso8601String());
      result.success = true;
    } catch (e) {
      result.errors.add('同步异常: $e');
    }

    return result;
  }

  Future<void> _pullLibraries() async {
    try {
      int skip = 0;
      const limit = 100;
      while (true) {
        final serverLibs = await _api.getLibraries(skip: skip, limit: limit);
        if (serverLibs.isEmpty) break;
        for (final lib in serverLibs) {
          await _db.upsertLibrary({
            'server_id': lib.id,
            'name': lib.name,
            'description': lib.description,
            'daily_new_cards': lib.dailyNewCards,
            'daily_review_limit': lib.dailyReviewLimit,
            'created_at': lib.createdAt,
            'updated_at': lib.updatedAt,
            'sync_status': 'synced',
          });
        }
        if (serverLibs.length < limit) break;
        skip += limit;
      }
    } catch (e) {
      // ignore pull errors to allow partial sync
    }
  }

  Future<void> _pullFlashcards() async {
    try {
      int skip = 0;
      const limit = 100;
      while (true) {
        final serverCards = await _api.getFlashcards(skip: skip, limit: limit);
        if (serverCards.isEmpty) break;
        for (final card in serverCards) {
          // Skip if local card is pending delete
          final existing = await _db.getFlashcardByServerId(card.id);
          if (existing != null && existing['sync_status'] == 'pending_delete') {
            continue;
          }

          // Map server library_id to local library_id
          final db = await _db.database;
          final libRows = await db.query('libraries', where: 'server_id = ?', whereArgs: [card.libraryId]);
          int localLibId = card.libraryId;
          if (libRows.isNotEmpty) {
            localLibId = libRows.first['id'] as int;
          }

          await _db.upsertFlashcard({
            'server_id': card.id,
            'front': card.front,
            'back': card.back,
            'library_id': localLibId,
            'difficulty': card.difficulty,
            'created_at': card.createdAt,
            'sync_status': 'synced',
          });
        }
        if (serverCards.length < limit) break;
        skip += limit;
      }
    } catch (e) {
      // ignore pull errors to allow partial sync
    }
  }

  Future<void> _pullStudyRecords() async {
    try {
      final records = await _api.getStudyRecords();
      final db = await _db.database;

      // 保护本地未同步的复习记录：跳过有待推送复习记录的卡片
      final pendingReviews = await _db.getPendingReviews();
      final pendingLocalIds = pendingReviews.map((r) => r['flashcard_id'] as int).toSet();

      // 服务器返回的 flashcard_id 集合
      final serverIds = records.map((r) => r['flashcard_id'] as int).toSet();

      // 本地有 server_id 但服务器没有对应 study_record 的，删除本地记录（重置效果）
      // 但跳过有待推送复习记录的卡片，避免丢失本地进度
      final localCards = await db.rawQuery(
        "SELECT id, server_id FROM flashcards WHERE server_id IS NOT NULL"
      );
      for (final card in localCards) {
        final sid = card['server_id'] as int;
        if (!serverIds.contains(sid) && !pendingLocalIds.contains(card['id'] as int)) {
          await db.delete('study_records', where: 'flashcard_id = ?', whereArgs: [card['id']]);
        }
      }

      // Upsert 服务器返回的记录，但跳过有待推送复习记录的卡片
      for (final r in records) {
        final serverCardId = r['flashcard_id'] as int;
        final cardRows = await db.query('flashcards', where: 'server_id = ?', whereArgs: [serverCardId]);
        if (cardRows.isEmpty) continue;
        final localId = cardRows.first['id'] as int;
        if (pendingLocalIds.contains(localId)) continue;
        await _db.upsertStudyRecordByServerId(
          serverCardId,
          {
            'interval_days': r['interval_days'] as int? ?? 0,
            'ease_factor': (r['ease_factor'] as num?)?.toDouble() ?? 2.5,
            'repetitions': r['repetitions'] as int? ?? 0,
            'next_review_at': r['next_review_at'],
            'last_review_at': r['last_review_at'],
          },
        );
      }
    } catch (e) {
      // ignore pull errors to allow partial sync
    }
  }

  Future<void> _pullStudyPlan() async {
    try {
      final plan = await _api.getStudyPlan();
      final db = await _db.database;
      final existing = await db.query('study_plan');
      final data = {
        'id': 1,
        'daily_new_cards': plan.dailyNewCards,
        'daily_review_limit': plan.dailyReviewLimit,
        'sync_status': 'synced',
      };
      if (existing.isEmpty) {
        await db.insert('study_plan', data);
      } else if (existing.first['sync_status'] == 'synced') {
        await db.update('study_plan', data);
      }
    } catch (_) {
      // ignore if no plan on server
    }
  }

  Future<void> _pullAlgorithmSettings() async {
    try {
      final settings = await _api.getAlgorithmSettings();
      await _db.saveAlgorithmSettings({
        'new_card_easy_interval': settings['new_card_easy_interval'] as int,
        'new_card_hard_interval': settings['new_card_hard_interval'] as int,
        'second_repetition_interval': settings['second_repetition_interval'] as int,
        'min_ease_factor': (settings['min_ease_factor'] as num).toDouble(),
        'initial_ease_factor': (settings['initial_ease_factor'] as num).toDouble(),
      });
    } catch (_) {
      // ignore if no settings on server
    }
  }

  Future<void> _pullDailyTask() async {
    try {
      final task = await _api.getDailyTask();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      if (task['date'] == null) {
        // 服务器没有当天记录（被重置了），删除本地当天记录
        final db = await _db.database;
        await db.delete('daily_tasks', where: 'date = ?', whereArgs: [todayStr]);
      } else if (task['date'] == todayStr) {
        final localTask = await _db.getDailyTask(todayStr);
        final localNewDone = localTask['new_cards_done'] as int? ?? 0;
        final localReviewDone = localTask['review_done'] as int? ?? 0;
        final serverNewDone = task['new_cards_done'] as int? ?? 0;
        final serverReviewDone = task['review_done'] as int? ?? 0;
        // 保护本地统计：如果服务器计数小于本地，保留本地（可能是pending_reviews还未push成功）
        await _db.saveDailyTask({
          'date': todayStr,
          'new_cards_done': serverNewDone > localNewDone ? serverNewDone : localNewDone,
          'review_done': serverReviewDone > localReviewDone ? serverReviewDone : localReviewDone,
          'sync_status': 'synced',
        });
      }
    } catch (_) {
      // ignore if no daily task on server
    }
  }
}

class SyncResult {
  bool success = false;
  int createdLibraries = 0;
  int updatedLibraries = 0;
  int deletedLibraries = 0;
  int createdFlashcards = 0;
  int updatedFlashcards = 0;
  int deletedFlashcards = 0;
  int syncedReviews = 0;
  List<String> errors = [];
}
