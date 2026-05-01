<template>
  <div>
    <el-card>
      <template #header>
        <span>提取任务</span>
      </template>
      <el-table :data="adminStore.jobs" stripe>
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="note_id" label="笔记ID" />
        <el-table-column prop="status" label="状态">
          <template #default="scope">
            <el-tag :type="statusType(scope.row.status)">{{ scope.row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="flashcard_count" label="生成卡片数" />
        <el-table-column label="进度信息" min-width="180">
          <template #default="scope">
            <span v-if="scope.row.progress_message" style="color: #409eff">{{ scope.row.progress_message }}</span>
            <span v-else-if="scope.row.error_message" style="color: #f56c6c">{{ scope.row.error_message }}</span>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" />
        <el-table-column label="操作" width="100">
          <template #default="scope">
            <el-button
              v-if="scope.row.status === 'pending' || scope.row.status === 'running'"
              size="small"
              type="danger"
              @click="handleCancel(scope.row.id)"
            >
              取消
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      <el-pagination
        style="margin-top: 16px"
        background
        layout="prev, pager, next"
        :total="adminStore.jobsTotal"
        :page-size="20"
        @current-change="handlePageChange"
      />
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted, ref, computed } from 'vue';
import { ElMessage, ElMessageBox } from 'element-plus';
import { useAdminStore } from '../stores/admin';

const adminStore = useAdminStore();
const timer = ref<ReturnType<typeof setInterval> | null>(null);

const hasRunning = computed(() => adminStore.jobs.some((j) => j.status === 'running' || j.status === 'pending'));

function startPolling() {
  if (timer.value) clearInterval(timer.value);
  const interval = hasRunning.value ? 2000 : 5000;
  adminStore.fetchJobs();
  timer.value = setInterval(() => {
    adminStore.fetchJobs();
    // 动态调整轮询频率
    const nextInterval = hasRunning.value ? 2000 : 5000;
    if (nextInterval !== interval && timer.value) {
      clearInterval(timer.value);
      timer.value = setInterval(() => adminStore.fetchJobs(), nextInterval);
    }
  }, interval);
}

onMounted(() => {
  startPolling();
});

onUnmounted(() => {
  if (timer.value) clearInterval(timer.value);
});

function handlePageChange(page: number) {
  adminStore.fetchJobs((page - 1) * 20, 20);
}

function statusType(status: string) {
  switch (status) {
    case 'completed': return 'success';
    case 'failed': return 'danger';
    case 'cancelled': return 'info';
    case 'running': return 'warning';
    default: return 'info';
  }
}

async function handleCancel(jobId: number) {
  try {
    await ElMessageBox.confirm('确定取消该提取任务吗？', '提示', { type: 'warning' });
    await adminStore.cancelJob(jobId);
    ElMessage.success('已取消');
    adminStore.fetchJobs();
  } catch {
    // cancelled
  }
}
</script>
