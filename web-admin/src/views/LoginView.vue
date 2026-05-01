<template>
  <div class="login-container">
    <el-card class="login-card" shadow="always">
      <h2 style="text-align: center; margin-bottom: 24px">闪卡系统后台</h2>
      <el-form :model="form" @submit.prevent="handleSubmit">
        <el-form-item>
          <el-input v-model="form.username" placeholder="用户名" prefix-icon="User" />
        </el-form-item>
        <el-form-item>
          <el-input v-model="form.password" type="password" placeholder="密码" prefix-icon="Lock" show-password />
        </el-form-item>
        <el-form-item>
          <el-button type="primary" style="width: 100%" :loading="loading" @click="handleSubmit">
            {{ isRegister ? '注册' : '登录' }}
          </el-button>
        </el-form-item>
        <el-form-item style="text-align: center">
          <el-link type="primary" @click="isRegister = !isRegister">
            {{ isRegister ? '已有账号？去登录' : '没有账号？去注册' }}
          </el-link>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue';
import { useRouter } from 'vue-router';
import { ElMessage } from 'element-plus';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const auth = useAuthStore();
const isRegister = ref(false);
const loading = ref(false);

const form = reactive({ username: '', password: '' });

async function handleSubmit() {
  if (!form.username || !form.password) {
    ElMessage.warning('请输入用户名和密码');
    return;
  }
  loading.value = true;
  try {
    if (isRegister.value) {
      await auth.register(form.username, form.password);
    } else {
      await auth.login(form.username, form.password);
    }
    ElMessage.success(isRegister.value ? '注册成功' : '登录成功');
    router.push('/dashboard');
  } catch (err: any) {
    ElMessage.error(err.response?.data?.message || '操作失败');
  } finally {
    loading.value = false;
  }
}
</script>

<style scoped>
.login-container {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #f5f7fa;
}
.login-card {
  width: 400px;
}
</style>
