class Flashcard {
  final int id;
  final String front;
  final String back;
  final int libraryId;
  final int difficulty;
  final String createdAt;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    required this.libraryId,
    required this.difficulty,
    required this.createdAt,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'],
      front: json['front'],
      back: json['back'],
      libraryId: json['library_id'],
      difficulty: json['difficulty'] ?? 0,
      createdAt: json['created_at'],
    );
  }
}

class TodayCard {
  final int flashcardId;
  final String front;
  final String back;
  final bool isNew;
  final int repetitions;
  final double easeFactor;
  final int intervalDays;

  TodayCard({
    required this.flashcardId,
    required this.front,
    required this.back,
    required this.isNew,
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
  });

  factory TodayCard.fromJson(Map<String, dynamic> json) {
    return TodayCard(
      flashcardId: json['flashcard_id'],
      front: json['front'],
      back: json['back'],
      isNew: json['is_new'],
      repetitions: json['repetitions'] ?? 0,
      easeFactor: (json['ease_factor'] ?? 2.5).toDouble(),
      intervalDays: json['interval_days'] ?? 0,
    );
  }
}

class StudyRecord {
  final int intervalDays;
  final double easeFactor;
  final int repetitions;
  final String? nextReviewAt;

  StudyRecord({
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitions,
    this.nextReviewAt,
  });

  factory StudyRecord.fromJson(Map<String, dynamic> json) {
    return StudyRecord(
      intervalDays: json['interval_days'] ?? 0,
      easeFactor: (json['ease_factor'] ?? 2.5).toDouble(),
      repetitions: json['repetitions'] ?? 0,
      nextReviewAt: json['next_review_at'],
    );
  }
}
