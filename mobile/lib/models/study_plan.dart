class StudyPlan {
  final int id;
  final int userId;
  final String name;
  final int dailyNewCards;
  final int dailyReviewLimit;

  StudyPlan({
    required this.id,
    required this.userId,
    required this.name,
    required this.dailyNewCards,
    required this.dailyReviewLimit,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      dailyNewCards: json['daily_new_cards'],
      dailyReviewLimit: json['daily_review_limit'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'daily_new_cards': dailyNewCards,
      'daily_review_limit': dailyReviewLimit,
    };
  }
}

class StudyStats {
  final int totalFlashcards;
  final int masteredFlashcards;
  final int reviewsToday;
  final int newCardsToday;
  final int streakDays;
  final List<int> weeklyReviews;

  StudyStats({
    required this.totalFlashcards,
    required this.masteredFlashcards,
    required this.reviewsToday,
    this.newCardsToday = 0,
    required this.streakDays,
    required this.weeklyReviews,
  });

  factory StudyStats.fromJson(Map<String, dynamic> json) {
    return StudyStats(
      totalFlashcards: json['total_flashcards'] ?? 0,
      masteredFlashcards: json['mastered_flashcards'] ?? 0,
      reviewsToday: json['reviews_today'] ?? 0,
      newCardsToday: json['new_cards_today'] ?? 0,
      streakDays: json['streak_days'] ?? 0,
      weeklyReviews: List<int>.from(json['weekly_reviews'] ?? []),
    );
  }
}
