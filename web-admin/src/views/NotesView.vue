<template>
  <div>
    <el-card>
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span>笔记管理</span>
          <div>
            <el-input v-model="search" placeholder="搜索笔记" style="width: 200px; margin-right: 8px" @keyup.enter="handleSearch" />
            <el-button type="primary" @click="handleSearch">搜索</el-button>
            <el-button type="danger" :disabled="selectedIds.length === 0" @click="handleBatchDelete">
              批量删除 ({{ selectedIds.length }})
            </el-button>
          </div>
        </div>
      </template>
      <el-table :data="notesStore.notes" v-loading="notesStore.loading" stripe @selection-change="handleSelectionChange">
        <el-table-column type="selection" width="55" />
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="title" label="标题" />
        <el-table-column prop="source_path" label="来源" />
        <el-table-column prop="updated_at" label="更新时间" />
        <el-table-column label="操作" width="220">
          <template #default="scope">
            <el-button size="small" type="primary" @click="handleExtract(scope.row)">提取</el-button>
            <el-button size="small" @click="handleView(scope.row)">查看</el-button>
            <el-button size="small" type="danger" @click="handleDelete(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <el-pagination
        style="margin-top: 16px"
        background
        layout="prev, pager, next"
        :total="notesStore.total"
        :page-size="20"
        @current-change="handlePageChange"
      />
    </el-card>

    <el-dialog v-model="showView" title="笔记详情" width="600px">
      <h3>{{ viewNote?.title }}</h3>
      <p style="white-space: pre-wrap">{{ viewNote?.content }}</p>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useNotesStore, type Note } from '../stores/notes';

const router = useRouter();

const notesStore = useNotesStore();
const search = ref('');
const showView = ref(false);
const viewNote = ref<Note | null>(null);
const selectedIds = ref<number[]>([]);

onMounted(() => {
  notesStore.fetchNotes();
});

function handleSelectionChange(rows: Note[]) {
  selectedIds.value = rows.map((r) => r.id);
}

function handleSearch() {
  notesStore.fetchNotes(0, 20, search.value);
}

function handlePageChange(page: number) {
  notesStore.fetchNotes((page - 1) * 20, 20, search.value);
}

function handleView(note: Note) {
  viewNote.value = note;
  showView.value = true;
}

async function handleDelete(id: number) {
  try {
    await ElMessageBox.confirm('确定删除该笔记吗？', '提示', { type: 'warning' });
    await notesStore.deleteNote(id);
    ElMessage.success('删除成功');
    notesStore.fetchNotes();
  } catch {
    // cancelled
  }
}

async function handleBatchDelete() {
  if (selectedIds.value.length === 0) return;
  try {
    await ElMessageBox.confirm(`确定删除选中的 ${selectedIds.value.length} 条笔记吗？`, '提示', { type: 'warning' });
    await notesStore.batchDeleteNotes(selectedIds.value);
    ElMessage.success('批量删除成功');
    selectedIds.value = [];
    notesStore.fetchNotes();
  } catch {
    // cancelled
  }
}

async function handleExtract(note: Note) {
  try {
    await notesStore.extractFlashcards(note.id);
    ElMessage.success({ message: '提取任务已启动，请前往“提取任务”页面查看进度', duration: 4000 });
    setTimeout(() => {
      router.push('/extraction-jobs');
    }, 800);
  } catch (err: any) {
    const msg = err.response?.data?.message || '提取失败';
    ElMessage.error(msg);
  }
}


</script>
