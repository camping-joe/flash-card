<template>
  <div>
    <el-card>
      <template #header>
        <span>算法参数配置</span>
      </template>
      <p style="color: #666; margin-bottom: 16px">
        调整 SM-2 间隔重复算法的参数，控制卡片复习间隔的增长速度。
      </p>
      <el-form :model="form" label-width="180px">
        <el-form-item label="新卡片简单间隔（天）">
          <el-input-number v-model="form.new_card_easy_interval" :min="1" :max="30" />
          <span style="color: #999; margin-left: 8px">选择"简单"后的首次复习间隔</span>
        </el-form-item>
        <el-form-item label="新卡片困难间隔（天）">
          <el-input-number v-model="form.new_card_hard_interval" :min="1" :max="10" />
          <span style="color: #999; margin-left: 8px">选择"良好/困难/重来"后的首次复习间隔</span>
        </el-form-item>
        <el-form-item label="第二次复习间隔（天）">
          <el-input-number v-model="form.second_repetition_interval" :min="1" :max="30" />
          <span style="color: #999; margin-left: 8px">第二次成功复习后的间隔</span>
        </el-form-item>
        <el-form-item label="最小易度因子">
          <el-slider v-model="form.min_ease_factor" :min="1.1" :max="2.0" :step="0.1" />
          <span style="color: #999; margin-left: 8px">易度因子下限，影响复习间隔最小增长速度</span>
        </el-form-item>
        <el-form-item label="初始易度因子">
          <el-slider v-model="form.initial_ease_factor" :min="2.0" :max="3.0" :step="0.1" />
          <span style="color: #999; margin-left: 8px">新卡片的初始易度，越大间隔增长越快</span>
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSave">保存配置</el-button>
          <el-button @click="handleReset">恢复默认</el-button>
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
  new_card_easy_interval: 3,
  new_card_hard_interval: 1,
  second_repetition_interval: 6,
  min_ease_factor: 1.3,
  initial_ease_factor: 2.5,
});

onMounted(async () => {
  await admin.fetchAlgorithmConfig();
  if (admin.algorithmConfig) {
    form.new_card_easy_interval = admin.algorithmConfig.new_card_easy_interval;
    form.new_card_hard_interval = admin.algorithmConfig.new_card_hard_interval;
    form.second_repetition_interval = admin.algorithmConfig.second_repetition_interval;
    form.min_ease_factor = admin.algorithmConfig.min_ease_factor;
    form.initial_ease_factor = admin.algorithmConfig.initial_ease_factor;
  }
});

async function handleSave() {
  try {
    await admin.updateAlgorithmConfig({ ...form });
    ElMessage.success('配置已保存');
  } catch (err: any) {
    ElMessage.error(err.response?.data?.message || '保存失败');
  }
}

function handleReset() {
  form.new_card_easy_interval = 3;
  form.new_card_hard_interval = 1;
  form.second_repetition_interval = 6;
  form.min_ease_factor = 1.3;
  form.initial_ease_factor = 2.5;
  ElMessage.info('已恢复默认值，请点击保存');
}
</script>
