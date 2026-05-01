<template>
  <div>
    <el-card>
      <template #header>
        <span>学习统计</span>
      </template>
      <el-row :gutter="16">
        <el-col :span="8">
          <div style="text-align: center; padding: 24px">
            <div style="font-size: 36px; font-weight: bold; color: #409eff">{{ stats?.total_flashcards || 0 }}</div>
            <div style="color: #666; margin-top: 8px">总闪卡数</div>
          </div>
        </el-col>
        <el-col :span="8">
          <div style="text-align: center; padding: 24px">
            <div style="font-size: 36px; font-weight: bold; color: #67c23a">{{ stats?.mastered_flashcards || 0 }}</div>
            <div style="color: #666; margin-top: 8px">已掌握</div>
          </div>
        </el-col>
        <el-col :span="8">
          <div style="text-align: center; padding: 24px">
            <div style="font-size: 36px; font-weight: bold; color: #e6a23c">{{ stats?.new_cards_today || 0 }}</div>
            <div style="color: #666; margin-top: 8px">今日新卡</div>
          </div>
        </el-col>
      </el-row>
    </el-card>

    <el-card style="margin-top: 16px">
      <template #header>
        <span>学习计划</span>
      </template>
      <el-form v-if="plan" :model="plan" label-width="140px">
        <el-form-item label="计划名称">
          <el-input v-model="plan.name" />
        </el-form-item>
        <el-form-item label="每日新卡上限">
          <el-input-number v-model="plan.daily_new_cards" :min="1" :max="100" />
        </el-form-item>
        <el-form-item label="每日复习上限">
          <el-input-number v-model="plan.daily_review_limit" :min="1" :max="500" />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" @click="handleSavePlan">保存计划</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { ElMessage } from 'element-plus';
import { useStudyStore } from '../stores/study';

const study = useStudyStore();
const stats = computed(() => study.stats);
const plan = computed(() => study.plan);

onMounted(() => {
  study.fetchStats();
  study.fetchPlan();
});

async function handleSavePlan() {
  if (!plan.value) return;
  try {
    await study.updatePlan({
      name: plan.value.name,
      daily_new_cards: plan.value.daily_new_cards,
      daily_review_limit: plan.value.daily_review_limit,
    });
    ElMessage.success('计划已保存');
  } catch (err: any) {
    ElMessage.error(err.response?.data?.message || '保存失败');
  }
}
</script>
