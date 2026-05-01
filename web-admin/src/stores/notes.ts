import { defineStore } from 'pinia';
import { ref } from 'vue';
import api from '../api/client';

export interface Note {
  id: number;
  title: string;
  content: string;
  source_path: string | null;
  user_id: number;
  created_at: string;
  updated_at: string;
}

export const useNotesStore = defineStore('notes', () => {
  const notes = ref<Note[]>([]);
  const total = ref(0);
  const loading = ref(false);

  async function fetchNotes(skip = 0, limit = 20, q = '') {
    loading.value = true;
    const res = await api.get('/api/notes', { params: { skip, limit, q } });
    notes.value = res.data.items;
    total.value = res.data.total;
    loading.value = false;
  }

  async function createNote(data: { title: string; content: string; source_path?: string }) {
    const res = await api.post('/api/notes', data);
    return res.data;
  }

  async function deleteNote(id: number) {
    await api.delete(`/api/notes/${id}`);
  }

  async function batchDeleteNotes(ids: number[]) {
    for (const id of ids) {
      await api.delete(`/api/notes/${id}`);
    }
  }

  async function extractFlashcards(noteId: number) {
    const res = await api.post(`/api/admin/notes/${noteId}/extract`);
    return res.data;
  }

  return { notes, total, loading, fetchNotes, createNote, deleteNote, batchDeleteNotes, extractFlashcards };
});
