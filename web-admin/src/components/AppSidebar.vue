<template>
  <el-aside width="200px" style="background: #304156; color: #fff; min-height: 100vh">
    <div style="padding: 16px; font-size: 18px; font-weight: bold; text-align: center">
      闪卡系统
    </div>
    <el-menu
      :default-active="$route.path"
      router
      background-color="#304156"
      text-color="#bfcbd9"
      active-text-color="#409eff"
      style="border-right: none"
    >
      <el-menu-item index="/dashboard">
        <el-icon><DataLine /></el-icon>
        <span>仪表盘</span>
      </el-menu-item>
      <el-menu-item index="/libraries">
        <el-icon><FolderOpened /></el-icon>
        <span>卡库管理</span>
      </el-menu-item>
      <el-menu-item index="/notes">
        <el-icon><Document /></el-icon>
        <span>笔记管理</span>
      </el-menu-item>
      <el-menu-item index="/flashcards">
        <el-icon><Collection /></el-icon>
        <span>闪卡管理</span>
      </el-menu-item>
      <el-menu-item index="/ai-config">
        <el-icon><SetUp /></el-icon>
        <span>AI 配置</span>
      </el-menu-item>
      <el-menu-item index="/algorithm-config">
        <el-icon><Setting /></el-icon>
        <span>算法配置</span>
      </el-menu-item>
      <el-menu-item index="/extraction-jobs">
        <el-icon><Loading /></el-icon>
        <span>提取任务</span>
      </el-menu-item>
      <el-menu-item index="/stats">
        <el-icon><TrendCharts /></el-icon>
        <span>学习统计</span>
      </el-menu-item>
      <el-menu-item index="/reset-progress">
        <el-icon><RefreshLeft /></el-icon>
        <span>重置进度</span>
      </el-menu-item>
    </el-menu>
  </el-aside>
</template>

<script setup lang="ts">
import { DataLine, Document, Collection, SetUp, Loading, TrendCharts, FolderOpened, Setting, RefreshLeft } from '@element-plus/icons-vue';
</script>
