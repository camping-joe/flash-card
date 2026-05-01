<template>
  <div>
    <el-card>
      <template #header>
        <span>重置学习进度</span>
      </template>
      <el-alert
        title="警告"
        type="warning"
        description="此操作将清除所有卡片的学习记录（包括复习间隔、熟练度、重复次数）以及每日学习统计。卡片本身不会被删除。"
        show-icon
        :closable="false"
        style="margin-bottom: 24px"
      />
      <el-button type="danger" size="large" @click="handleReset" :loading="loading">
        确认重置所有学习进度
      </el-button>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useStudyStore } from '../stores/study';

const studyStore = useStudyStore();
const loading = ref(false);

async function handleReset() {
  try {
    await ElMessageBox.confirm(
      '确定要重置所有学习进度吗？此操作不可恢复！',
      '危险操作',
      { confirmButtonText: '确定重置', cancelButtonText: '取消', type: 'warning' }
    );
    loading.value = true;
    await studyStore.resetProgress();
    ElMessage.success('学习进度已重置');
  } catch (err: any) {
    if (err !== 'cancel') {
      const msg = err.response?.data?.message || '重置失败';
      ElMessage.error(msg);
    }
  } finally {
    loading.value = false;
  }
}
</script>
