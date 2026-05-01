import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../models/study_plan.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<StudyProvider>(context, listen: false).loadPlan());
  }

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    final plan = study.plan;

    if (plan == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('学习计划', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _SettingRow(
                    label: '每日新卡上限',
                    value: plan.dailyNewCards,
                    onChanged: (v) => _updatePlan(plan.copyWith(dailyNewCards: v)),
                  ),
                  const Divider(),
                  _SettingRow(
                    label: '每日复习上限',
                    value: plan.dailyReviewLimit,
                    onChanged: (v) => _updatePlan(plan.copyWith(dailyReviewLimit: v)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePlan(StudyPlan newPlan) async {
    await Provider.of<StudyProvider>(context, listen: false).updatePlan(newPlan);
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _SettingRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: value > 1 ? () => onChanged(value - 1) : null),
            Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add), onPressed: () => onChanged(value + 1)),
          ],
        ),
      ],
    );
  }
}

extension on StudyPlan {
  StudyPlan copyWith({int? dailyNewCards, int? dailyReviewLimit}) {
    return StudyPlan(
      id: id,
      userId: userId,
      name: name,
      dailyNewCards: dailyNewCards ?? this.dailyNewCards,
      dailyReviewLimit: dailyReviewLimit ?? this.dailyReviewLimit,
    );
  }
}
