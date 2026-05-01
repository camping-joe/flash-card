import { requestUrl, RequestUrlParam } from 'obsidian';

export class FlashcardAPI {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
  }

  async login(username: string, password: string): Promise<void> {
    const res = await requestUrl({
      url: `${this.baseUrl}/api/auth/login`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const data = res.json;
    if (data.access_token) {
      this.token = data.access_token;
    } else {
      throw new Error(data.message || 'Login failed');
    }
  }

  async pushNote(title: string, content: string, sourcePath: string): Promise<void> {
    if (!this.token) {
      throw new Error('Not authenticated');
    }
    const res = await requestUrl({
      url: `${this.baseUrl}/api/notes/push`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${this.token}`,
      },
      body: JSON.stringify({ title, content, source_path: sourcePath }),
    });
    if (res.status !== 200) {
      const data = res.json;
      throw new Error(data.message || `Push failed (${res.status})`);
    }
  }

  isAuthenticated(): boolean {
    return this.token !== null;
  }
}
