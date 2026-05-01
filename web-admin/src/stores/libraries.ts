import { defineStore } from 'pinia';
import { ref } from 'vue';
import api from '../api/client';

export interface Library {
  id: number;
  name: string;
  description: string | null;
  daily_new_cards: number | null;
  daily_review_limit: number | null;
  user_id: number;
  created_at: string;
  updated_at: string;
}

export const useLibrariesStore = defineStore('libraries', () => {
  const libraries = ref<Library[]>([]);
  const total = ref(0);

  async function fetchLibraries(skip = 0, limit = 20) {
    const res = await api.get('/api/libraries', { params: { skip, limit } });
    libraries.value = res.data.items;
    total.value = res.data.total;
  }

  async function createLibrary(data: { name: string; description?: string; daily_new_cards?: number | null; daily_review_limit?: number | null }) {
    const res = await api.post('/api/libraries', data);
    return res.data;
  }

  async function updateLibrary(id: number, data: { name?: string; description?: string; daily_new_cards?: number | null; daily_review_limit?: number | null }) {
    const res = await api.put(`/api/libraries/${id}`, data);
    return res.data;
  }

  async function deleteLibrary(id: number) {
    await api.delete(`/api/libraries/${id}`);
  }

  return { libraries, total, fetchLibraries, createLibrary, updateLibrary, deleteLibrary };
});
