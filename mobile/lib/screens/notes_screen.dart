import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../models/note.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<StudyProvider>(context, listen: false).loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNoteDialog(context),
          ),
        ],
      ),
      body: study.loading
          ? const Center(child: CircularProgressIndicator())
          : study.notes.isEmpty
              ? const Center(child: Text('暂无笔记，点击右上角添加'))
              : ListView.builder(
                  itemCount: study.notes.length,
                  itemBuilder: (context, index) {
                    final note = study.notes[index];
                    return Dismissible(
                      key: Key('note_${note.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, note),
                      onDismissed: (_) => study.deleteNote(note.id),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _showNoteDialog(context, note: note),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Note note) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: Text('确定要删除 "${note.title}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return result ?? false;
  }

  void _showNoteDialog(BuildContext context, {Note? note}) {
    final titleCtrl = TextEditingController(text: note?.title ?? '');
    final contentCtrl = TextEditingController(text: note?.content ?? '');
    final isEdit = note != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? '编辑笔记' : '添加笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: '标题'),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              decoration: const InputDecoration(labelText: '内容'),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (title.isEmpty || content.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('标题和内容不能为空')));
                return;
              }
              Navigator.of(ctx).pop();
              final study = Provider.of<StudyProvider>(context, listen: false);
              try {
                if (isEdit) {
                  await study.updateNote(note.id, title, content);
                } else {
                  await study.createNote(title, content);
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
      ),
    );
  }
}
