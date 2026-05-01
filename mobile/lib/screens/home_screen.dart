import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/study_provider.dart';
import 'login_screen.dart';
import 'study_screen.dart';
import 'card_library_screen.dart';
import 'plan_screen.dart';
import 'stats_screen.dart';
import 'library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = const [
    _TodayTab(),
    LibraryScreen(),
    CardLibraryScreen(),
    PlanScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('闪卡学习'),
        actions: [
          if (study.isOffline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(label: Text('离线', style: TextStyle(fontSize: 12)), backgroundColor: Colors.orange, labelStyle: TextStyle(color: Colors.white)),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '同步',
            onPressed: () async {
              final result = await study.sync();
              if (mounted) {
                if (result.success && result.errors.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('同步成功'), duration: Duration(seconds: 2)),
                  );
                } else if (result.success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('同步完成，部分失败: ${result.errors.join(", ")}'), duration: const Duration(seconds: 4)),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('同步失败: ${result.errors.join(", ")}'), duration: const Duration(seconds: 4)),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: '今日'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: '卡库'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: '卡片'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '计划'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
        ],
      ),
    );
  }
}

class _TodayTab extends StatefulWidget {
  const _TodayTab();

  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final study = Provider.of<StudyProvider>(context, listen: false);
      await study.sync();
      await study.loadToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    return RefreshIndicator(
      onRefresh: () => study.loadToday(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (study.lastSyncTime != null)
            Text('上次同步: ${study.lastSyncTime!.substring(0, 19).replaceAll('T', ' ')}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('${study.reviewCount}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const Text('待复习'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('${study.newCount}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green)),
                        const Text('新卡片'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('${study.reviewsToday}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const Text('今日已复习', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('${study.newCardsToday}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.purple)),
                        const Text('今日新卡已学', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (study.todayCards.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudyScreen()));
                },
                child: const Text('开始学习', style: TextStyle(fontSize: 18)),
              ),
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: Text('今日学习任务已完成！', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}
