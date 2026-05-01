import { defineStore } from 'pinia';
import { ref } from 'vue';
import api from '../api/client';

export interface AIConfig {
  id: number;
  user_id: number;
  provider: string;
  base_url: string;
  model: string;
  temperature: number;
  max_tokens: number;
}

export interface AlgorithmConfig {
  id: number;
  user_id: number;
  new_card_easy_interval: number;
  new_card_hard_interval: number;
  second_repetition_interval: number;
  min_ease_factor: number;
  initial_ease_factor: number;
}

export interface ExtractionJob {
  id: number;
  note_id: number | null;
  status: string;
  flashcard_count: number;
  error_message: string | null;
  progress_message: string | null;
  created_at: string;
  completed_at: string | null;
}

export const useAdminStore = defineStore('admin', () => {
  const aiConfig = ref<AIConfig | null>(null);
  const algorithmConfig = ref<AlgorithmConfig | null>(null);
  const jobs = ref<ExtractionJob[]>([]);
  const jobsTotal = ref(0);

  async function fetchAIConfig() {
    const res = await api.get('/api/admin/ai-config');
    aiConfig.value = res.data;
  }

  async function updateAIConfig(data: Partial<AIConfig> & { api_key?: string }) {
    const res = await api.put('/api/admin/ai-config', data);
    aiConfig.value = res.data;
  }

  async function fetchAlgorithmConfig() {
    const res = await api.get('/api/admin/algorithm-settings');
    algorithmConfig.value = res.data;
  }

  async function updateAlgorithmConfig(data: Partial<AlgorithmConfig>) {
    const res = await api.put('/api/admin/algorithm-settings', data);
    algorithmConfig.value = res.data;
  }

  async function fetchJobs(skip = 0, limit = 20) {
    const res = await api.get('/api/admin/extraction-jobs', { params: { skip, limit } });
    jobs.value = res.data.items;
    jobsTotal.value = res.data.total;
  }

  async function cancelJob(jobId: number) {
    const res = await api.post(`/api/admin/extraction-jobs/${jobId}/cancel`);
    return res.data;
  }

  return { aiConfig, algorithmConfig, jobs, jobsTotal, fetchAIConfig, updateAIConfig, fetchAlgorithmConfig, updateAlgorithmConfig, fetchJobs, cancelJob };
});
