import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  bool _showAnswer = false;
  int _currentIndex = 0;
  int _totalCards = 0;

  @override
  void initState() {
    super.initState();
    final study = Provider.of<StudyProvider>(context, listen: false);
    _totalCards = study.todayCards.length;
  }

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    final cards = study.todayCards;

    if (cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('学习')),
        body: const Center(child: Text('今日学习任务已完成！')),
      );
    }

    if (_currentIndex >= _totalCards) {
      return Scaffold(
        appBar: AppBar(title: const Text('学习完成')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text('今日学习完成！', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      );
    }

    final card = cards[0];

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1} / $_totalCards'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('结束', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showAnswer = true),
                child: Card(
                  elevation: 4,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (card.isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                            child: const Text('新卡片', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        const SizedBox(height: 24),
                        Text(card.front, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        if (_showAnswer) ...[
                          const Divider(height: 48),
                          Text(card.back, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
                        ] else ...[
                          const SizedBox(height: 48),
                          const Text('点击查看答案', style: TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showAnswer)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    const Text('你觉得这张卡片的难度？', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RatingButton(
                            label: '重来',
                            color: Colors.red,
                            preview: _formatInterval(_previewInterval(card.repetitions, card.easeFactor, card.intervalDays, 1)),
                            onPressed: () => _rate(1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RatingButton(
                            label: '困难',
                            color: Colors.orange,
                            preview: _formatInterval(_previewInterval(card.repetitions, card.easeFactor, card.intervalDays, 2)),
                            onPressed: () => _rate(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RatingButton(
                            label: '良好',
                            color: Colors.blue,
                            preview: _formatInterval(_previewInterval(card.repetitions, card.easeFactor, card.intervalDays, 3)),
                            onPressed: () => _rate(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RatingButton(
                            label: '简单',
                            color: Colors.green,
                            preview: _formatInterval(_previewInterval(card.repetitions, card.easeFactor, card.intervalDays, 4)),
                            onPressed: () => _rate(4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _previewInterval(int repetitions, double easeFactor, int interval, int rating) {
    final study = Provider.of<StudyProvider>(context, listen: false);
    final settings = study.algorithmSettings;
    if (rating < 3) return settings.newCardHardInterval;
    if (repetitions == 0) return rating == 4 ? settings.newCardEasyInterval : settings.newCardHardInterval;
    if (repetitions == 1) return settings.secondRepetitionInterval;
    return (interval * easeFactor).round();
  }

  String _formatInterval(int days) {
    if (days <= 1) return '明天';
    if (days < 30) return '${days}天后';
    if (days < 365) return '${days ~/ 30}个月后';
    return '${days ~/ 365}年后';
  }

  Future<void> _rate(int rating) async {
    final study = Provider.of<StudyProvider>(context, listen: false);
    final card = study.todayCards[0];
    await study.reviewCard(card.flashcardId, rating);
    setState(() {
      _showAnswer = false;
      _currentIndex++;
    });
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final String preview;

  const _RatingButton({required this.label, required this.color, required this.onPressed, required this.preview});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(preview, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
