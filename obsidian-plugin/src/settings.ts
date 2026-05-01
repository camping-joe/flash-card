export interface FlashcardPluginSettings {
  baseUrl: string;
  username: string;
  password: string;
  autoSync: boolean;
  syncDelayMs: number;
}

export const DEFAULT_SETTINGS: FlashcardPluginSettings = {
  baseUrl: 'http://192.168.3.11:8887',
  username: '',
  password: '',
  autoSync: true,
  syncDelayMs: 3000,
};
