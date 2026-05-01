<template>
  <div>
    <el-card>
      <template #header>
        <span>AI 配置</span>
      </template>
      <el-form :model="form" label-width="120px">
        <el-form-item label="提供商">
          <el-input v-model="form.provider" placeholder="kimi" />
        </el-form-item>
        <el-form-item label="Base URL">
          <el-input v-model="form.base_url" placeholder="https://api.moonshot.cn/v1" />
        </el-form-item>
        <el-form-item label="API Key">
          <el-input v-model="form.api_key" type="password" placeholder="输入 API Key" show-password />
        </el-form-item>
        <el-form-item label="模型">
          <el-input v-model="form.model" placeholder="moonshot-v1-8k" />
        </el-form-item>
        <el-form-item label="Temperature">
          <el-slider v-model="form.temperature" :min="0" :max="2" :step="0.1" />
        </el-form-item>
        <el-form-item label="Max Tokens">
          <el-input-number v-model="form.max_tokens" :min="1" :max="8192" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSave">保存配置</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { reactive, onMounted } from 'vue';
import { ElMessage } from 'element-plus';
import { useAdminStore } from '../stores/admin';

const admin = useAdminStore();

const form = reactive({
  provider: 'kimi',
  base_url: 'https://api.moonshot.cn/v1',
  api_key: '',
  model: 'moonshot-v1-8k',
  temperature: 0.3,
  max_tokens: 2048,
});

onMounted(async () => {
  await admin.fetchAIConfig();
  if (admin.aiConfig) {
    form.provider = admin.aiConfig.provider;
    form.base_url = admin.aiConfig.base_url;
    form.model = admin.aiConfig.model;
    form.temperature = admin.aiConfig.temperature;
    form.max_tokens = admin.aiConfig.max_tokens;
  }
});

async function handleSave() {
  try {
    await admin.updateAIConfig({ ...form });
    ElMessage.success('配置已保存');
  } catch (err: any) {
    ElMessage.error(err.response?.data?.message || '保存失败');
  }
}
</script>
