class Library {
  final int id;
  final String name;
  final String? description;
  final int? dailyNewCards;
  final int? dailyReviewLimit;
  final String createdAt;
  final String updatedAt;

  Library({
    required this.id,
    required this.name,
    this.description,
    this.dailyNewCards,
    this.dailyReviewLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      dailyNewCards: json['daily_new_cards'],
      dailyReviewLimit: json['daily_review_limit'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
