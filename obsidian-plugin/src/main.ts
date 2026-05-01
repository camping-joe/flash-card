import { App, Plugin, PluginSettingTab, Setting, TFile, Notice } from 'obsidian';
import { FlashcardPluginSettings, DEFAULT_SETTINGS } from './settings';
import { FlashcardAPI } from './api';

export default class FlashcardSyncPlugin extends Plugin {
  settings: FlashcardPluginSettings;
  api: FlashcardAPI;
  statusBarEl: HTMLElement;
  private syncTimer: number | null = null;
  private modifiedFiles = new Set<string>();

  async onload() {
    await this.loadSettings();
    this.api = new FlashcardAPI(this.settings.baseUrl);

    this.addSettingTab(new FlashcardSettingTab(this.app, this));

    this.statusBarEl = this.addStatusBarItem();
    this.statusBarEl.setText('闪卡: 未登录');

    this.addRibbonIcon('upload', '推送当前笔记到闪卡系统', () => {
      this.pushCurrentNote();
    });

    this.addCommand({
      id: 'push-current-note',
      name: '推送当前笔记到闪卡系统',
      callback: () => this.pushCurrentNote(),
    });

    this.addCommand({
      id: 'login-to-flashcard',
      name: '登录闪卡系统',
      callback: () => this.login(),
    });

    this.registerEvent(
      this.app.vault.on('modify', (file) => {
        if (!this.settings.autoSync) return;
        if (file instanceof TFile && file.extension === 'md') {
          this.modifiedFiles.add(file.path);
          this.debounceSync();
        }
      })
    );

    if (this.settings.username && this.settings.password) {
      this.login().catch(() => {
        this.updateStatus('登录失败');
      });
    }
  }

  onunload() {
    if (this.syncTimer !== null) {
      window.clearTimeout(this.syncTimer);
    }
  }

  async loadSettings() {
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
  }

  async saveSettings() {
    await this.saveData(this.settings);
  }

  async login(): Promise<void> {
    try {
      this.api = new FlashcardAPI(this.settings.baseUrl);
      await this.api.login(this.settings.username, this.settings.password);
      this.updateStatus('已登录');
      new Notice('闪卡系统登录成功');
    } catch (e) {
      this.updateStatus('登录失败');
      new Notice(`登录失败: ${e.message}`);
      throw e;
    }
  }

  async pushCurrentNote(): Promise<void> {
    const file = this.app.workspace.getActiveFile();
    if (!file || file.extension !== 'md') {
      new Notice('请先打开一个 Markdown 笔记');
      return;
    }
    await this.pushFile(file);
  }

  async pushFile(file: TFile): Promise<void> {
    if (!this.api.isAuthenticated()) {
      try {
        await this.login();
      } catch {
        new Notice('请先配置账号密码并登录');
        return;
      }
    }

    try {
      this.updateStatus('推送中...');
      const content = await this.app.vault.read(file);
      await this.api.pushNote(file.basename, content, file.path);
      this.updateStatus('推送成功');
      new Notice(`已推送: ${file.basename}`);
    } catch (e) {
      this.updateStatus('推送失败');
      new Notice(`推送失败: ${e.message}`);
    }
  }

  private debounceSync() {
    if (!this.settings.autoSync) return;
    if (this.syncTimer !== null) {
      window.clearTimeout(this.syncTimer);
    }
    this.syncTimer = window.setTimeout(() => {
      this.syncModifiedFiles();
    }, this.settings.syncDelayMs);
  }

  private async syncModifiedFiles() {
    if (!this.settings.autoSync) return;
    if (!this.api.isAuthenticated()) return;

    for (const path of Array.from(this.modifiedFiles)) {
      const file = this.app.vault.getAbstractFileByPath(path);
      if (file instanceof TFile) {
        try {
          await this.pushFile(file);
        } catch {
          // ignore individual failures
        }
      }
    }
    this.modifiedFiles.clear();
  }

  private updateStatus(text: string) {
    this.statusBarEl.setText(`闪卡: ${text}`);
  }
}

class FlashcardSettingTab extends PluginSettingTab {
  plugin: FlashcardSyncPlugin;

  constructor(app: App, plugin: FlashcardSyncPlugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display() {
    const { containerEl } = this;
    containerEl.empty();

    containerEl.createEl('h2', { text: '闪卡同步设置' });

    new Setting(containerEl)
      .setName('服务器地址')
      .setDesc('后端 API 地址')
      .addText((text) =>
        text
          .setPlaceholder('http://192.168.3.11:8887')
          .setValue(this.plugin.settings.baseUrl)
          .onChange(async (value) => {
            this.plugin.settings.baseUrl = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName('用户名')
      .setDesc('闪卡系统用户名')
      .addText((text) =>
        text
          .setPlaceholder('username')
          .setValue(this.plugin.settings.username)
          .onChange(async (value) => {
            this.plugin.settings.username = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName('密码')
      .setDesc('闪卡系统密码')
      .addText((text) =>
        text
          .setPlaceholder('password')
          .setValue(this.plugin.settings.password)
          .onChange(async (value) => {
            this.plugin.settings.password = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName('保存时自动推送')
      .setDesc('笔记保存后自动推送到闪卡系统')
      .addToggle((toggle) =>
        toggle
          .setValue(this.plugin.settings.autoSync)
          .onChange(async (value) => {
            this.plugin.settings.autoSync = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName('推送延迟')
      .setDesc('保存后延迟多少毫秒推送（防抖）')
      .addSlider((slider) =>
        slider
          .setLimits(1000, 10000, 500)
          .setValue(this.plugin.settings.syncDelayMs)
          .setDynamicTooltip()
          .onChange(async (value) => {
            this.plugin.settings.syncDelayMs = value;
            await this.plugin.saveSettings();
          })
      );

    new Setting(containerEl)
      .setName('测试登录')
      .setDesc('验证账号密码是否正确')
      .addButton((btn) =>
        btn
          .setButtonText('登录')
          .onClick(() => this.plugin.login())
      );
  }
}
