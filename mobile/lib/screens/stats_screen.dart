import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<StudyProvider>(context, listen: false).loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    final stats = study.stats;

    if (stats == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => study.loadStats(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          Row(
            children: [
              Expanded(child: _StatCard(title: '总闪卡', value: stats.totalFlashcards, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: '已掌握', value: stats.masteredFlashcards, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(title: '今日新卡', value: stats.newCardsToday, color: Colors.purple)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: '今日复习', value: stats.reviewsToday, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('近7天复习', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (stats.weeklyReviews.isEmpty)
                    const Text('暂无数据', style: TextStyle(color: Colors.grey))
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: stats.weeklyReviews.asMap().entries.map((e) {
                        final days = ['一', '二', '三', '四', '五', '六', '日'];
                        return Column(
                          children: [
                            Text('${e.value}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(days[e.key], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
