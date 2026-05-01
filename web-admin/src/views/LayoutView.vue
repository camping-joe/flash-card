<template>
  <el-container style="height: 100vh">
    <AppSidebar />
    <el-container>
      <el-header style="background: #fff; display: flex; align-items: center; justify-content: space-between; box-shadow: 0 1px 4px rgba(0,0,0,0.1)">
        <span></span>
        <el-dropdown @command="handleCommand">
          <span style="cursor: pointer">
            {{ auth.username }} <el-icon><ArrowDown /></el-icon>
          </span>
          <template #dropdown>
            <el-dropdown-menu>
              <el-dropdown-item command="logout">退出登录</el-dropdown-item>
            </el-dropdown-menu>
          </template>
        </el-dropdown>
      </el-header>
      <el-main style="background: #f0f2f5; padding: 20px">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { ArrowDown } from '@element-plus/icons-vue';
import AppSidebar from '../components/AppSidebar.vue';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const auth = useAuthStore();

function handleCommand(cmd: string) {
  if (cmd === 'logout') {
    auth.logout();
    router.push('/login');
  }
}
</script>
