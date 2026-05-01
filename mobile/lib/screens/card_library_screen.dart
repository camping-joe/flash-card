import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../models/flashcard.dart';

class CardLibraryScreen extends StatefulWidget {
  const CardLibraryScreen({super.key});

  @override
  State<CardLibraryScreen> createState() => _CardLibraryScreenState();
}

class _CardLibraryScreenState extends State<CardLibraryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final study = Provider.of<StudyProvider>(context, listen: false);
      study.loadFlashcards();
      study.loadLibraries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('卡片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCardDialog(context),
          ),
        ],
      ),
      body: study.loading
          ? const Center(child: CircularProgressIndicator())
          : study.flashcards.isEmpty
              ? const Center(child: Text('暂无卡片，点击右上角添加'))
              : ListView.builder(
                  itemCount: study.flashcards.length,
                  itemBuilder: (context, index) {
                    final card = study.flashcards[index];
                    return Dismissible(
                      key: Key('card_${card.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, card),
                      onDismissed: (_) => study.deleteFlashcard(card.id),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(card.back, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onTap: () => _showCardDialog(context, card: card),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Flashcard card) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除卡片'),
        content: Text('确定要删除 "${card.front}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return result ?? false;
  }

  void _showCardDialog(BuildContext context, {Flashcard? card}) {
    final frontCtrl = TextEditingController(text: card?.front ?? '');
    final backCtrl = TextEditingController(text: card?.back ?? '');
    final isEdit = card != null;
    int? selectedLibraryId = card?.libraryId;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final study = Provider.of<StudyProvider>(context, listen: false);
            final libraries = study.libraries;

            return AlertDialog(
              title: Text(isEdit ? '编辑卡片' : '添加卡片'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: frontCtrl,
                      decoration: const InputDecoration(labelText: '正面'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: backCtrl,
                      decoration: const InputDecoration(labelText: '背面'),
                      maxLines: 3,
                    ),
                    if (libraries.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: selectedLibraryId,
                        decoration: const InputDecoration(labelText: '所属卡库 *'),
                        hint: const Text('选择卡库'),
                        items: libraries.map((lib) => DropdownMenuItem<int>(
                          value: lib.id,
                          child: Text(lib.name, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setState(() => selectedLibraryId = val),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      const Text('暂无卡库，请先到"卡库"页面添加', style: TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
                TextButton(
                  onPressed: () async {
                    final front = frontCtrl.text.trim();
                    final back = backCtrl.text.trim();
                    if (front.isEmpty || back.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正反面不能为空')));
                      return;
                    }
                    if (selectedLibraryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择所属卡库')));
                      return;
                    }
                    Navigator.of(ctx).pop();
                    try {
                      if (isEdit) {
                        await study.updateFlashcard(card.id, front, back, libraryId: selectedLibraryId!);
                      } else {
                        await study.createFlashcard(front, back, libraryId: selectedLibraryId!);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                      }
                    }
                  },
                  child: Text(isEdit ? '保存' : '添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
