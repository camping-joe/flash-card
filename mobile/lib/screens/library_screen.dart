import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/study_provider.dart';
import '../models/library.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => Provider.of<StudyProvider>(context, listen: false).loadLibraries());
  }

  @override
  Widget build(BuildContext context) {
    final study = Provider.of<StudyProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('卡库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showLibraryDialog(context),
          ),
        ],
      ),
      body: study.loading
          ? const Center(child: CircularProgressIndicator())
          : study.libraries.isEmpty
              ? const Center(child: Text('暂无卡库，点击右上角添加'))
              : ListView.builder(
                  itemCount: study.libraries.length,
                  itemBuilder: (context, index) {
                    final lib = study.libraries[index];
                    return Dismissible(
                      key: Key('lib_${lib.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, lib),
                      onDismissed: (_) => study.deleteLibrary(lib.id),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(lib.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: lib.description != null
                              ? Text(lib.description!, maxLines: 2, overflow: TextOverflow.ellipsis)
                              : null,
                          onTap: () => _showLibraryDialog(context, library: lib),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Library library) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除卡库'),
        content: Text('确定要删除 "${library.name}" 吗？该卡库下的所有卡片也会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return result ?? false;
  }

  void _showLibraryDialog(BuildContext context, {Library? library}) {
    final nameCtrl = TextEditingController(text: library?.name ?? '');
    final descCtrl = TextEditingController(text: library?.description ?? '');
    final isEdit = library != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? '编辑卡库' : '添加卡库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '名称'),
              maxLines: 1,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: '描述（可选）'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名称不能为空')));
                return;
              }
              Navigator.of(ctx).pop();
              final study = Provider.of<StudyProvider>(context, listen: false);
              try {
                if (isEdit) {
                  await study.updateLibrary(library.id, name, description: descCtrl.text.trim());
                } else {
                  await study.createLibrary(name, description: descCtrl.text.trim());
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
