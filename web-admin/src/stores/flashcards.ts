import { defineStore } from 'pinia';
import { ref } from 'vue';
import api from '../api/client';

export interface Flashcard {
  id: number;
  front: string;
  back: string;
  library_id: number;
  difficulty: number;
  user_id: number;
  created_at: string;
}

export const useFlashcardsStore = defineStore('flashcards', () => {
  const flashcards = ref<Flashcard[]>([]);
  const total = ref(0);

  async function fetchFlashcards(skip = 0, limit = 20, libraryId?: number) {
    const res = await api.get('/api/flashcards', { params: { skip, limit, library_id: libraryId } });
    flashcards.value = res.data.items;
    total.value = res.data.total;
  }

  async function updateFlashcard(id: number, data: Partial<Flashcard>) {
    const res = await api.put(`/api/flashcards/${id}`, data);
    return res.data;
  }

  async function deleteFlashcard(id: number) {
    await api.delete(`/api/flashcards/${id}`);
  }

  async function fetchAllIds(libraryId?: number) {
    const res = await api.get('/api/flashcards/all-ids', { params: { library_id: libraryId } });
    return res.data.ids as number[];
  }

  async function batchDeleteFlashcards(ids: number[]) {
    await api.delete('/api/flashcards/batch', { data: { ids } });
  }

  async function batchUpdateLibrary(ids: number[], libraryId: number) {
    await api.put('/api/flashcards/batch/library', { ids, library_id: libraryId });
  }

  return { flashcards, total, fetchFlashcards, updateFlashcard, deleteFlashcard, batchDeleteFlashcards, batchUpdateLibrary, fetchAllIds };
});
