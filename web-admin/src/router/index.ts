import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', name: 'login', component: () => import('../views/LoginView.vue') },
    {
      path: '/',
      component: () => import('../views/LayoutView.vue'),
      redirect: '/dashboard',
      children: [
        { path: 'dashboard', name: 'dashboard', component: () => import('../views/DashboardView.vue') },
        { path: 'libraries', name: 'libraries', component: () => import('../views/LibrariesView.vue') },
        { path: 'notes', name: 'notes', component: () => import('../views/NotesView.vue') },
        { path: 'flashcards', name: 'flashcards', component: () => import('../views/FlashcardsView.vue') },
        { path: 'ai-config', name: 'ai-config', component: () => import('../views/AIConfigView.vue') },
        { path: 'algorithm-config', name: 'algorithm-config', component: () => import('../views/AlgorithmConfigView.vue') },
        { path: 'extraction-jobs', name: 'extraction-jobs', component: () => import('../views/ExtractionJobsView.vue') },
        { path: 'stats', name: 'stats', component: () => import('../views/StatsView.vue') },
        { path: 'reset-progress', name: 'reset-progress', component: () => import('../views/ResetProgressView.vue') },
      ],
    },
  ],
});

router.beforeEach((to) => {
  const auth = useAuthStore();
  if (to.path !== '/login' && !auth.isLoggedIn) {
    return '/login';
  }
});

export default router;
