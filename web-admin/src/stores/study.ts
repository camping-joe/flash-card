import { defineStore } from 'pinia';
import { ref } from 'vue';
import api from '../api/client';

export interface StudyPlan {
  id: number;
  user_id: number;
  name: string;
  daily_new_cards: number;
  daily_review_limit: number;
}

export interface Stats {
  total_flashcards: number;
  mastered_flashcards: number;
  reviews_today: number;
  new_cards_today: number;
  streak_days: number;
  weekly_reviews: number[];
}

export const useStudyStore = defineStore('study', () => {
  const plan = ref<StudyPlan | null>(null);
  const stats = ref<Stats | null>(null);

  async function fetchPlan() {
    const res = await api.get('/api/study/plan');
    plan.value = res.data;
  }

  async function updatePlan(data: Partial<StudyPlan>) {
    const res = await api.put('/api/study/plan', data);
    plan.value = res.data;
  }

  async function fetchStats() {
    const res = await api.get('/api/study/stats');
    stats.value = res.data;
  }

  async function resetProgress() {
    const res = await api.post('/api/study/reset-progress');
    return res.data;
  }

  return { plan, stats, fetchPlan, updatePlan, fetchStats, resetProgress };
});
