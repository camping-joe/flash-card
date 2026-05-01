<template>
  <div>
    <el-row :gutter="16">
      <el-col :span="6">
        <el-card>
          <div style="color: #666; font-size: 14px">总笔记数</div>
          <div style="font-size: 28px; font-weight: bold; margin-top: 8px">{{ stats?.total_flashcards || 0 }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <div style="color: #666; font-size: 14px">总闪卡数</div>
          <div style="font-size: 28px; font-weight: bold; margin-top: 8px">{{ stats?.total_flashcards || 0 }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <div style="color: #666; font-size: 14px">今日新卡</div>
          <div style="font-size: 28px; font-weight: bold; margin-top: 8px">{{ stats?.new_cards_today || 0 }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <div style="color: #666; font-size: 14px">今日复习</div>
          <div style="font-size: 28px; font-weight: bold; margin-top: 8px">{{ stats?.reviews_today || 0 }}</div>
        </el-card>
      </el-col>
      <el-col :span="6">
        <el-card>
          <div style="color: #666; font-size: 14px">已掌握</div>
          <div style="font-size: 28px; font-weight: bold; margin-top: 8px">{{ stats?.mastered_flashcards || 0 }}</div>
        </el-card>
      </el-col>
    </el-row>
    <el-card style="margin-top: 16px">
      <template #header>
        <span>近7天学习趋势</span>
      </template>
      <div style="height: 300px; display: flex; align-items: center; justify-content: center; color: #999">
        图表组件（后续可接入 ECharts）
      </div>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { useStudyStore } from '../stores/study';

const study = useStudyStore();
const stats = study.stats;

onMounted(() => {
  study.fetchStats();
});
</script>
