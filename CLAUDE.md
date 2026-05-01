# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个闪卡学习系统，包含四个子项目：

- **backend/**：FastAPI + SQLAlchemy（异步）+ PostgreSQL 服务端
- **mobile/**：Flutter 离线优先的移动应用，支持与服务端同步
- **web-admin/**：Vue 3 + TypeScript + Vite 管理后台
- **obsidian-plugin/**：Obsidian 插件，用于将笔记推送到闪卡系统

## 常用命令

### 后端

```bash
cd backend
# 先激活虚拟环境（venv/）
# 启动服务
uvicorn app.main:app --reload --host 0.0.0.0 --port 8887
# 运行全部测试
pytest
# 运行单个测试文件
pytest tests/test_sm2.py
# 运行单个测试方法
pytest tests/test_sm2.py::test_calculate_sm2 -v
# 数据库迁移
alembic revision --autogenerate -m "description"
alembic upgrade head
```

后端依赖见 `requirements.txt`。项目未配置 linter 或 formatter。

### 移动端

```bash
cd mobile
# 在已连接的设备或模拟器上运行
flutter run
# 构建 APK
flutter build apk
# 运行测试
flutter test
```

### Web 管理后台

```bash
cd web-admin
npm run dev      # 启动开发服务器
npm run build    # 生产构建
```

API 基础地址默认为 `http://192.168.3.11:8887`，可通过 `VITE_API_URL` 覆盖。

### Obsidian 插件

```bash
cd obsidian-plugin
npm run dev      # 监听模式（esbuild）
npm run build    # 生产构建
```

插件将 `src/main.ts` 打包为 `main.js`。

## 高层架构

### 后端

- **入口**：`app/main.py` 注册路由、CORS 中间件和异常处理器。
- **路由**（`app/api/`）：`auth`、`notes`、`flashcards`、`libraries`、`study`、`admin`。受保护的路由使用 `get_current_user` 依赖注入；认证路由公开。
- **依赖**（`app/core/dependencies.py`）：`get_db()` 生成异步 SQLAlchemy 会话，出错时自动回滚；`get_current_user()` 通过 `OAuth2PasswordBearer` 验证 JWT。
- **安全**（`app/core/security.py`）：bcrypt 密码哈希、JWT 编解码、Fernet 加密 AI API 密钥。`ENCRYPTION_KEY` 不足 32 字节时会自动补零。
- **异常处理**（`app/core/exceptions.py`）：自定义 `AppException` 层次结构（`NotFoundException`、`UnauthorizedException`、`BadRequestException`）。处理器返回 HTTP 200，响应体为 `{"code": ..., "message": ..., "data": null}`，而非标准 HTTP 状态码。
- **模型**（`app/models/models.py`）：SQLAlchemy 声明式基类，包含 `User`、`Library`、`Note`、`Flashcard`、`StudyRecord`、`StudyPlan`、`DailyTask`、`AIConfig`、`AlgorithmSettings`、`ExtractionJob`。用户拥有的实体均级联删除。
- **SM-2 算法**（`app/services/sm2.py`）：基于重复次数、 ease factor 和 1-4 评分计算下次复习间隔。参数通过 `AlgorithmSettings` 按用户配置。
- **AI 提取**（`app/services/ai_extractor.py`）：按 Markdown 标题拆分笔记，调用配置的 LLM（默认 Kimi/Moonshot）生成中文闪卡，返回规范化 JSON。包含对 LLM 异常输出的防御性 JSON 解析。
- **提取任务**（`app/api/admin.py`）：异步后台任务（`_run_extraction`）创建 `ExtractionJob` 记录，通过 AI 逐章节提取闪卡并更新进度，最后插入关联的 `Library`。超时随章节数动态计算：`max(300, 章节数 * 90)` 秒。
- **配置**（`app/core/config.py`）：Pydantic-settings 从 `.env` 读取。关键变量：`DATABASE_URL`、`SECRET_KEY`、`ENCRYPTION_KEY`。
- **测试**（`tests/conftest.py`）：使用与应用程序相同的 `DATABASE_URL`（真实的 PostgreSQL），通过覆盖 `get_db` 提供测试会话。表由模型使用隐式创建，没有显式的测试数据库创建或销毁逻辑，仅做会话清理。

### 移动端（离线优先）

- **本地数据库**：`sqflite`，表包括 `libraries`、`flashcards`、`study_records`、`study_plan`、`pending_reviews`、`daily_tasks`、`algorithm_settings`、`sync_metadata`。
- **同步模型**：每次本地修改都会给行标记 `sync_status`（`pending_create`、`pending_update`、`pending_delete`）。`SyncService` 先将待推送的变更发送到服务端，再拉取服务端数据。复习记录进入 `pending_reviews` 队列，在同步时推送。同步过程中，如果本地每日任务计数高于服务端，会保留本地值（避免未发送的复习记录导致进度丢失）。
- **学习流程**：`StudyProvider` 从本地数据库加载今日卡片（`getTodayCards`），应用每日新卡/复习上限。评分后，`Sm2Service.calculate()` 更新本地 `study_records` 并将复习记录加入待推送队列。
- **离线支持**：应用完全支持离线使用；同步是显式的（用户触发或在线时自动同步）。
- **API 基础地址**：默认 `http://192.168.3.11:8887`，存储在 `SharedPreferences` 中，用户可配置。

### Web 管理后台

- **状态**：Pinia store 位于 `src/stores/`（`auth`、`admin`、`flashcards`、`libraries`、`notes`、`study`）。
- **路由**：`src/router/index.ts` 对非登录路由使用 `useAuthStore.isLoggedIn` 进行守卫。
- **API 客户端**：`src/api/client.ts` 是 Axios 实例，自动从 `localStorage` 附加 `Bearer` token，遇到 401 时重定向到 `/login`。
- **视图**：Dashboard、Libraries、Notes、Flashcards、AI Config、Algorithm Config、Extraction Jobs、Stats、Reset Progress。

### Obsidian 插件

- **主插件**（`src/main.ts`）：注册推送当前笔记和登录的命令。监听 `vault.on('modify')` 事件，对 `.md` 文件进行防抖后自动推送（若开启 `autoSync`）。
- **API**（`src/api.ts`）：使用 Obsidian 的 `requestUrl` 进行登录和笔记推送。笔记推送到 `/api/notes/push`，该接口会自动创建或复用与笔记标题同名的 `Library`。

## 重要的跨项目关注点

- **算法一致性**：SM-2 逻辑存在于三个地方：`backend/app/services/sm2.py`、`mobile/lib/services/sm2_service.dart`、以及 web-admin（通过后端 API）。参数变更时必须保持三者同步。
- **评分语义**：1 = 重来（重置），2 = 困难，3 = 良好，4 = 简单。评分为 1 时在任何地方都不计入每日新卡/复习统计。
- **每日任务跟踪**：后端和移动端都跟踪每日新卡和复习次数。同步时，移动端会保护本地计数（若高于服务端则保留本地），避免待推送复习记录导致的进度丢失。
- **卡库迁移**：`migrate_library.py` 脚本（一次性运行）将 `flashcards` 上旧的 `note_id` 结构迁移到新的 `library_id` 结构。闪卡现在按 `Library` 分组，不再直接关联 `Note`。
- **加密密钥长度**：`ENCRYPTION_KEY` 至少需要 32 字节。安全模块会对较短的密钥补零。
