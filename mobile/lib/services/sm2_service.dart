class Sm2Result {
  final int repetitions;
  final double easeFactor;
  final int interval;
  final DateTime nextReviewAt;

  Sm2Result({
    required this.repetitions,
    required this.easeFactor,
    required this.interval,
    required this.nextReviewAt,
  });
}

class AlgorithmSettings {
  final int newCardEasyInterval;
  final int newCardHardInterval;
  final int secondRepetitionInterval;
  final double minEaseFactor;

  AlgorithmSettings({
    this.newCardEasyInterval = 3,
    this.newCardHardInterval = 1,
    this.secondRepetitionInterval = 6,
    this.minEaseFactor = 1.3,
  });
}

class Sm2Service {
  static Sm2Result calculate(
    int repetitions,
    double easeFactor,
    int interval,
    int rating, {
    AlgorithmSettings? settings,
  }) {
    final s = settings ?? AlgorithmSettings();

    if (rating < 3) {
      repetitions = 0;
      interval = rating == 1 ? 0 : s.newCardHardInterval;
    } else {
      if (repetitions == 0) {
        interval = rating == 4 ? s.newCardEasyInterval : s.newCardHardInterval;
      } else if (repetitions == 1) {
        interval = s.secondRepetitionInterval;
      } else {
        interval = (interval * easeFactor).round();
      }
      repetitions += 1;
    }

    easeFactor = [s.minEaseFactor, easeFactor + 0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02)].reduce((a, b) => a > b ? a : b);

    final nextReviewAt = DateTime.now().toUtc().add(Duration(days: interval));

    return Sm2Result(
      repetitions: repetitions,
      easeFactor: easeFactor,
      interval: interval,
      nextReviewAt: nextReviewAt,
    );
  }

  static String formatInterval(int days) {
    if (days == 1) return '明天';
    if (days < 7) return '${days}天后';
    if (days < 30) return '${(days / 7).round()}周后';
    return '${(days / 30).round()}个月后';
  }
}
