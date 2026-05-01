<template>
  <div>
    <el-card>
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span>闪卡管理</span>
          <div style="display: flex; gap: 8px">
            <el-button :disabled="effectiveSelectedCount === 0" @click="showBatchLibrary = true">
              修改卡库 ({{ effectiveSelectedCount }})
            </el-button>
            <el-button type="danger" :disabled="effectiveSelectedCount === 0" @click="handleBatchDelete">
              批量删除 ({{ effectiveSelectedCount }})
            </el-button>
          </div>
        </div>
      </template>
      <div v-if="selectAllMode || selectedIds.length > 0" style="margin-bottom: 12px; padding: 8px 12px; background: #f0f9ff; border-radius: 4px; display: flex; align-items: center; gap: 12px">
        <span v-if="selectAllMode">
          已选中全部 {{ flashcardsStore.total }} 条
          <el-button link type="primary" @click="cancelSelectAll">取消全选</el-button>
        </span>
        <span v-else>
          已选 {{ selectedIds.length }} 条
          <el-button link type="primary" @click="selectAll">选中全部 {{ flashcardsStore.total }} 条</el-button>
        </span>
      </div>
      <el-table
        ref="tableRef"
        :data="flashcardsStore.flashcards"
        stripe
        row-key="id"
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="55" reserve-selection />
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="front" label="问题" show-overflow-tooltip />
        <el-table-column prop="back" label="答案" show-overflow-tooltip />
        <el-table-column prop="library_id" label="卡库ID" width="80" />
        <el-table-column prop="difficulty" label="难度" width="80" />
        <el-table-column label="操作" width="120">
          <template #default="scope">
            <el-button size="small" @click="handleEdit(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="handleDelete(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <el-pagination
        style="margin-top: 16px"
        background
        layout="prev, pager, next"
        :total="flashcardsStore.total"
        :page-size="20"
        @current-change="handlePageChange"
      />
    </el-card>

    <el-dialog v-model="showEdit" title="编辑闪卡" width="500px">
      <el-form :model="editForm">
        <el-form-item label="问题">
          <el-input v-model="editForm.front" type="textarea" />
        </el-form-item>
        <el-form-item label="答案">
          <el-input v-model="editForm.back" type="textarea" />
        </el-form-item>
        <el-form-item label="卡库ID">
          <el-input-number v-model="editForm.library_id" :min="1" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showEdit = false">取消</el-button>
        <el-button type="primary" @click="submitEdit">保存</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showBatchLibrary" title="批量修改卡库" width="400px">
      <el-form>
        <el-form-item label="目标卡库">
          <el-select v-model="batchLibraryId" placeholder="请选择卡库" style="width: 100%">
            <el-option
              v-for="lib in librariesStore.libraries"
              :key="lib.id"
              :label="lib.name"
              :value="lib.id"
            />
          </el-select>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showBatchLibrary = false">取消</el-button>
        <el-button type="primary" @click="submitBatchLibrary" :disabled="!batchLibraryId">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import type { ElTable } from 'element-plus';
import { useFlashcardsStore, type Flashcard } from '../stores/flashcards';
import { useLibrariesStore } from '../stores/libraries';

const flashcardsStore = useFlashcardsStore();
const librariesStore = useLibrariesStore();
const tableRef = ref<InstanceType<typeof ElTable>>();
const showEdit = ref(false);
const editingId = ref(0);
const selectedIds = ref<number[]>([]);
const selectAllMode = ref(false);
const showBatchLibrary = ref(false);
const batchLibraryId = ref<number | undefined>(undefined);
const editForm = reactive({ front: '', back: '', library_id: 1 });

const effectiveSelectedCount = computed(() => {
  return selectAllMode.value ? flashcardsStore.total : selectedIds.value.length;
});

onMounted(() => {
  flashcardsStore.fetchFlashcards();
  librariesStore.fetchLibraries(0, 100);
});

function handleSelectionChange(rows: Flashcard[]) {
  selectedIds.value = rows.map((r) => r.id);
  if (selectAllMode.value && rows.length < flashcardsStore.flashcards.length) {
    // User manually deselected something on current page, exit select-all mode
    selectAllMode.value = false;
  }
}

async function selectAll() {
  try {
    const ids = await flashcardsStore.fetchAllIds();
    selectAllMode.value = true;
    selectedIds.value = ids;
    ElMessage.success(`已选中全部 ${ids.length} 条闪卡`);
  } catch {
    ElMessage.error('获取全部闪卡失败');
  }
}

function cancelSelectAll() {
  selectAllMode.value = false;
  selectedIds.value = [];
  tableRef.value?.clearSelection();
}

function handlePageChange(page: number) {
  flashcardsStore.fetchFlashcards((page - 1) * 20, 20);
}

function handleEdit(card: Flashcard) {
  editingId.value = card.id;
  editForm.front = card.front;
  editForm.back = card.back;
  editForm.library_id = card.library_id;
  showEdit.value = true;
}

async function submitEdit() {
  await flashcardsStore.updateFlashcard(editingId.value, { ...editForm });
  ElMessage.success('保存成功');
  showEdit.value = false;
  flashcardsStore.fetchFlashcards();
}

async function handleDelete(id: number) {
  try {
    await ElMessageBox.confirm('确定删除该闪卡吗？', '提示', { type: 'warning' });
    await flashcardsStore.deleteFlashcard(id);
    ElMessage.success('删除成功');
    flashcardsStore.fetchFlashcards();
  } catch {
    // cancelled
  }
}

async function handleBatchDelete() {
  const count = effectiveSelectedCount.value;
  if (count === 0) return;
  try {
    await ElMessageBox.confirm(`确定删除选中的 ${count} 张闪卡吗？`, '提示', { type: 'warning' });
    const ids = selectAllMode.value ? await flashcardsStore.fetchAllIds() : selectedIds.value;
    await flashcardsStore.batchDeleteFlashcards(ids);
    ElMessage.success('批量删除成功');
    selectAllMode.value = false;
    selectedIds.value = [];
    tableRef.value?.clearSelection();
    flashcardsStore.fetchFlashcards();
  } catch {
    // cancelled
  }
}

async function submitBatchLibrary() {
  if (!batchLibraryId.value || effectiveSelectedCount.value === 0) return;
  try {
    const count = effectiveSelectedCount.value;
    const ids = selectAllMode.value ? await flashcardsStore.fetchAllIds() : selectedIds.value;
    await flashcardsStore.batchUpdateLibrary(ids, batchLibraryId.value);
    ElMessage.success(`批量修改卡库成功，共 ${count} 张`);
    showBatchLibrary.value = false;
    batchLibraryId.value = undefined;
    selectAllMode.value = false;
    selectedIds.value = [];
    tableRef.value?.clearSelection();
    flashcardsStore.fetchFlashcards();
  } catch {
    ElMessage.error('批量修改失败');
  }
}
</script>
