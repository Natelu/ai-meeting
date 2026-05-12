# AI Meeting — CLAUDE.md

面向中小企业的私有化 AI 会议基础设施。数据主权优先，核心价值：AI 纪要、会议检索、资产归档。

## 仓库结构

```
apps/web/          Next.js 15 + React 19 前端（会议入口、管理后台、回放、检索）
services/api/      Go 控制面 API（Gin + pgx + sqlc + goose）
services/jobs/     Go 会后处理（Asynq worker：转写编排、摘要、归档）
packages/contracts/ 前后端共享类型契约（TypeScript）
infra/docker/      本地与试点 Docker Compose、Prometheus/Loki 配置
config/            存储、身份、OA 配置样例
docs/              产品定义、架构、接口契约、路线图
```

## 本地开发

### 先决条件

- Go 1.23+、Node.js 22 LTS、Docker Desktop（Compose v2）
- 复制环境变量：`cp .env.example .env`

### 启动中间件

```bash
make compose-local      # 启动 postgres / redis / minio / livekit
```

首次启动后需初始化 MinIO bucket（详见 `docs/superpowers/plans/2026-05-12-e2e-dev-middleware.md`）。

### 启动应用

```bash
make dev-api            # services/api → :8080
make dev-web            # apps/web    → :3000
```

### 测试与构建

```bash
make test               # 跑全部测试（api + jobs + web）
make build-web          # Next.js 生产构建
```

## 技术栈

| 层 | 选型 |
|---|---|
| 前端 | Next.js 15、React 19、TypeScript、Tailwind CSS、shadcn/ui、TanStack Query |
| 控制面后端 | Go 1.23、Gin、pgx、sqlc、goose |
| 异步任务 | Asynq、Redis |
| 实时音视频 | LiveKit（自部署） |
| 数据库 | PostgreSQL 16 |
| 对象存储 | S3 兼容（开发期用 MinIO） |
| ASR | FunASR / SenseVoice（备选 faster-whisper） |
| LLM | vLLM + Qwen2.5-Instruct（OpenAI-compatible API；Apple Silicon 用 Ollama） |
| 可观测 | Prometheus、Grafana、Loki |

## 核心端口

| 服务 | 端口 |
|---|---|
| Web | 3000 |
| API | 8080 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| MinIO API / Console | 9000 / 9001 |
| LiveKit | 7880 |
| ASR | 9001 |
| LLM (vLLM / Ollama) | 8000 / 11434 |
| Prometheus | 9090 |
| Grafana | 3001 |

## 开发规范

### Go 后端

- 所有 SQL 通过 **sqlc** 生成，不用 ORM
- 数据库迁移通过 **goose**（`services/api/db/migrations/`）
- 存储访问统一经过 **Storage Adapter**，业务代码不直接依赖 S3/NAS 实现
- 配置从环境变量读取（`services/api/internal/config/`）；`POSTGRES_DSN`、`REDIS_ADDR`、`S3_*`、`LIVEKIT_*`、`ASR_BASE_URL`、`LLM_BASE_URL`
- API 服务需暴露 `/healthz` 和 `/metrics`

### 前端

- 类型契约来自 `packages/contracts/`，不在前端重复定义
- 当前 `apps/web` 仍使用 mock 数据；接入真实 API 时对齐契约类型

### 通用

- 先写失败测试再实现（TDD）
- 不引入向量数据库、不自研 RTC、不做 Electron 客户端（v1 范围外）
- AI 服务（ASR、LLM）以独立 HTTP 服务接入，不嵌入主后端

## 关键文档

- 产品定义与范围：`docs/product-definition.md`
- 技术栈决策：`docs/concept-and-stack.md`
- 系统架构：`docs/system-architecture.md`
- 接口契约草案：`docs/interfaces.md`
- 路线图：`docs/roadmap.md`
- 端到端调试搭建计划：`docs/superpowers/plans/2026-05-12-e2e-dev-middleware.md`
