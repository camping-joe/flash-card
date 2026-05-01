<template>
  <div>
    <el-card>
      <template #header>
        <div style="display: flex; justify-content: space-between; align-items: center">
          <span>卡库管理</span>
          <el-button type="success" @click="showCreate = true">新建卡库</el-button>
        </div>
      </template>
      <el-table :data="librariesStore.libraries" stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="name" label="名称" />
        <el-table-column prop="description" label="描述" show-overflow-tooltip />
        <el-table-column label="每日新卡" width="100">
          <template #default="scope">
            <span>{{ scope.row.daily_new_cards ?? '默认' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="每日复习" width="100">
          <template #default="scope">
            <span>{{ scope.row.daily_review_limit ?? '默认' }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="updated_at" label="更新时间" />
        <el-table-column label="操作" width="180">
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
        :total="librariesStore.total"
        :page-size="20"
        @current-change="handlePageChange"
      />
    </el-card>

    <el-dialog v-model="showCreate" title="新建卡库" width="500px">
      <el-form :model="createForm">
        <el-form-item label="名称">
          <el-input v-model="createForm.name" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="createForm.description" type="textarea" />
        </el-form-item>
        <el-form-item label="每日新卡上限">
          <el-input-number v-model="createForm.daily_new_cards" :min="1" :max="100" placeholder="留空使用默认" />
        </el-form-item>
        <el-form-item label="每日复习上限">
          <el-input-number v-model="createForm.daily_review_limit" :min="1" :max="500" placeholder="留空使用默认" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showCreate = false">取消</el-button>
        <el-button type="primary" @click="submitCreate">确定</el-button>
      </template>
    </el-dialog>

    <el-dialog v-model="showEdit" title="编辑卡库" width="500px">
      <el-form :model="editForm">
        <el-form-item label="名称">
          <el-input v-model="editForm.name" />
        </el-form-item>
        <el-form-item label="描述">
          <el-input v-model="editForm.description" type="textarea" />
        </el-form-item>
        <el-form-item label="每日新卡上限">
          <el-input-number v-model="editForm.daily_new_cards" :min="1" :max="100" placeholder="留空使用默认" />
        </el-form-item>
        <el-form-item label="每日复习上限">
          <el-input-number v-model="editForm.daily_review_limit" :min="1" :max="500" placeholder="留空使用默认" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showEdit = false">取消</el-button>
        <el-button type="primary" @click="submitEdit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useLibrariesStore, type Library } from '../stores/libraries';

const librariesStore = useLibrariesStore();
const showCreate = ref(false);
const showEdit = ref(false);
const editingId = ref(0);
const createForm = reactive({ name: '', description: '', daily_new_cards: null as number | null, daily_review_limit: null as number | null });
const editForm = reactive({ name: '', description: '', daily_new_cards: null as number | null, daily_review_limit: null as number | null });

onMounted(() => {
  librariesStore.fetchLibraries();
});

function handlePageChange(page: number) {
  librariesStore.fetchLibraries((page - 1) * 20, 20);
}

function handleEdit(lib: Library) {
  editingId.value = lib.id;
  editForm.name = lib.name;
  editForm.description = lib.description || '';
  editForm.daily_new_cards = lib.daily_new_cards;
  editForm.daily_review_limit = lib.daily_review_limit;
  showEdit.value = true;
}

async function submitCreate() {
  await librariesStore.createLibrary({
    name: createForm.name,
    description: createForm.description || undefined,
    daily_new_cards: createForm.daily_new_cards,
    daily_review_limit: createForm.daily_review_limit,
  });
  ElMessage.success('创建成功');
  showCreate.value = false;
  createForm.name = '';
  createForm.description = '';
  createForm.daily_new_cards = null;
  createForm.daily_review_limit = null;
  librariesStore.fetchLibraries();
}

async function submitEdit() {
  await librariesStore.updateLibrary(editingId.value, {
    name: editForm.name,
    description: editForm.description || undefined,
    daily_new_cards: editForm.daily_new_cards,
    daily_review_limit: editForm.daily_review_limit,
  });
  ElMessage.success('保存成功');
  showEdit.value = false;
  librariesStore.fetchLibraries();
}

async function handleDelete(id: number) {
  try {
    await ElMessageBox.confirm('确定删除该卡库吗？该卡库下的所有卡片也会被删除。', '提示', { type: 'warning' });
    await librariesStore.deleteLibrary(id);
    ElMessage.success('删除成功');
    librariesStore.fetchLibraries();
  } catch {
    // cancelled
  }
}
</script>
