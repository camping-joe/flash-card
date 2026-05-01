import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../api/client';

export const useAuthStore = defineStore('auth', () => {
  const token = ref(localStorage.getItem('token') || '');
  const username = ref('');
  const isLoggedIn = computed(() => !!token.value);

  async function login(user: string, pass: string) {
    const res = await api.post('/api/auth/login', { username: user, password: pass });
    token.value = res.data.access_token;
    username.value = user;
    localStorage.setItem('token', token.value);
  }

  async function register(user: string, pass: string) {
    const res = await api.post('/api/auth/register', { username: user, password: pass });
    token.value = res.data.access_token;
    username.value = user;
    localStorage.setItem('token', token.value);
  }

  function logout() {
    token.value = '';
    username.value = '';
    localStorage.removeItem('token');
  }

  return { token, username, isLoggedIn, login, register, logout };
});
