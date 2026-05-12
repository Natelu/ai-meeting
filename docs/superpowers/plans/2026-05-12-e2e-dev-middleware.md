# 端到端开发调试中间件搭建计划

> 适用阶段：从 MVP scaffold（[2026-04-20-ai-meeting-mvp.md](2026-04-20-ai-meeting-mvp.md) Task 1–6 已落代码）走向真实端到端调试。
> 目标：让 Web → API → Jobs → RTC/录制 → ASR → LLM → 存储 这一整条链路在本机/单机能跑通，并具备可观测性，方便后续替换 mock 为真实实现。
> 不在范围：试点客户私有化部署、HA/灾备、TLS 证书签发、生产级 SLO。

---

## 0. 前置准备

### 0.1 主机要求

- macOS 13+ 或 Linux x86_64（Apple Silicon 需注意 vLLM 不支持，方案 B 会用 Ollama 替代）
- 内存 ≥ 16 GB（仅基础中间件 ≤ 4 GB；加 ASR/LLM 需 ≥ 12 GB 可用）
- 磁盘 ≥ 50 GB 可用（模型权重 + 录制文件）
- Docker Desktop 或 Docker Engine ≥ 24，Docker Compose v2

### 0.2 工具链

- Go 1.23+
- Node.js 22 LTS + npm
- FFmpeg（本机或容器内，用于录制转码与 ASR 输入预处理）
- `mc`（MinIO 客户端，可选；用 docker exec 也行）
- `psql`（可选，用于直接连 PostgreSQL 调试）
- `redis-cli`（可选）

### 0.3 .env 准备

```bash
cp .env.example .env
```

需要按下面"中间件配置"章节逐项检查 `.env`，至少更新：

- `LIVEKIT_API_KEY` / `LIVEKIT_API_SECRET`（开发期可用默认 `devkey/devsecret`，但 livekit.yaml 必须一致）
- `MINIO_ROOT_PASSWORD`（避免默认弱口令）
- `S3_BUCKET`（首次启动后需手动创建）
- `ASR_BASE_URL` / `LLM_BASE_URL`（按方案 A/B 选择）

---

## 1. 必须搭建的中间件清单

| 组件 | 用途 | 镜像 | 端口 | 必需性 |
| --- | --- | --- | --- | --- |
| PostgreSQL 16 | 会议/用户/任务元数据 | `postgres:16` | 5432 | 必须 |
| Redis 7 | 任务队列（Asynq）、缓存、会话 | `redis:7` | 6379 | 必须 |
| MinIO | 本地 S3 兼容对象存储（录制、转写、纪要、导出） | `minio/minio` | 9000 / 9001 | 必须 |
| LiveKit Server | WebRTC SFU、房间、egress 录制、webhook | `livekit/livekit-server:latest` | 7880 / 7881 / 7882 udp | 必须 |
| ASR 服务 | 录制 → 转写 | 方案 A：`registry.cn-shanghai.aliyuncs.com/funasr/funasr-runtime-sdk-cpu` <br> 方案 B：`onerahmet/openai-whisper-asr-webservice` | 9001 | 端到端跑摘要前必须 |
| LLM 服务 | 转写 → 摘要 / 待办 | 方案 A：`vllm/vllm-openai`（需 GPU） <br> 方案 B：`ollama/ollama`（CPU/Apple Silicon 可跑） | 8000 | 端到端跑摘要前必须 |
| Prometheus | 抓取 `/metrics` | `prom/prometheus:v3.0.1` | 9090 | 建议 |
| Grafana | 看板 | `grafana/grafana:11.4.0` | 3001 | 建议 |
| Loki | 日志聚合 | `grafana/loki:3.3.2` | 3100 | 可选 |

> 现状对照：[infra/docker/docker-compose.local.yml](../../../infra/docker/docker-compose.local.yml) 已经包含 postgres、redis、minio、livekit；**缺 ASR、LLM、prometheus、grafana、loki**，需要本计划补齐。

---

## 2. 中间件配置与启动

### 2.1 基础四件套（已有，校验即可）

```bash
docker compose --env-file .env -f infra/docker/docker-compose.local.yml up -d
docker compose -f infra/docker/docker-compose.local.yml ps
```

期望 4 个 service 全部 `healthy`。

#### PostgreSQL 初始化

```bash
# 进入容器
docker compose -f infra/docker/docker-compose.local.yml exec postgres \
  psql -U ai_meeting -d ai_meeting -c "\dt"
```

- 现阶段没有 migration（plan Phase 1 才接入 sqlc/goose），先确认连通；
- 后续 Task：新增 `services/api/db/migrations/0001_init.sql` 并跑 goose。

#### Redis 校验

```bash
docker compose -f infra/docker/docker-compose.local.yml exec redis redis-cli ping
# 期望: PONG
```

#### MinIO 初始化

需要手动建 bucket，否则录制写入会 404：

```bash
docker compose -f infra/docker/docker-compose.local.yml exec minio \
  sh -c 'mc alias set local http://localhost:9000 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD \
         && mc mb -p local/meeting-assets \
         && mc anonymous set download local/meeting-assets'
```

控制台：http://localhost:9001 （用户名 `minioadmin`，密码 `MINIO_ROOT_PASSWORD`）。

#### LiveKit 校验

- WebSocket URL：`ws://localhost:7880`
- API key/secret：来自 [infra/docker/livekit.yaml](../../../infra/docker/livekit.yaml) 的 `keys:`
- Webhook：`livekit.yaml` 默认指向 `http://api:8080/webhooks/livekit`；本机 API 直接跑（非容器）时需要改为 `http://host.docker.internal:8080/webhooks/livekit`

```bash
curl http://localhost:7880
# 期望 200 / 健康响应
```

### 2.2 ASR 服务（新增）

#### 方案 A：FunASR（推荐，中文效果好）

向 [infra/docker/docker-compose.local.yml](../../../infra/docker/docker-compose.local.yml) 追加：

```yaml
  asr:
    image: registry.cn-shanghai.aliyuncs.com/funasr/funasr-runtime-sdk-cpu:latest
    command: >
      sh -c "cd /workspace/FunASR/runtime &&
             bash run_server.sh --download-model-dir /workspace/models
             --vad-dir damo/speech_fsmn_vad_zh-cn-16k-common-onnx
             --model-dir damo/speech_paraformer-large_asr_nat-zh-cn-16k-common-vocab8404-onnx
             --punc-dir damo/punc_ct-transformer_zh-cn-common-vocab272727-onnx"
    ports:
      - "9001:10095"
    volumes:
      - funasr-models:/workspace/models
    healthcheck:
      test: ["CMD", "sh", "-c", "echo > /dev/tcp/127.0.0.1/10095"]
      interval: 30s
      timeout: 5s
      retries: 10
```

并在 `volumes:` 块新增 `funasr-models:`。

首次启动会下载 ≈ 2 GB 模型，耐心等待 5–15 min。

#### 方案 B：Whisper（无 GPU 也能跑，适合开发期快速验证）

```yaml
  asr:
    image: onerahmet/openai-whisper-asr-webservice:latest-cpu
    environment:
      ASR_MODEL: base
      ASR_ENGINE: faster_whisper
    ports:
      - "9001:9000"
```

> `.env` 中 `ASR_BASE_URL=http://localhost:9001`（若 API 也在容器内，用 `http://asr:9001`）。

#### 校验

```bash
curl -F "audio_file=@samples/hello.wav" http://localhost:9001/asr
```

### 2.3 LLM 服务（新增）

#### 方案 A：vLLM + Qwen2.5（需要 NVIDIA GPU ≥ 16 GB 显存）

```yaml
  vllm:
    image: vllm/vllm-openai:latest
    command: >
      --model Qwen/Qwen2.5-7B-Instruct
      --served-model-name qwen2.5-instruct
      --port 8000
    runtime: nvidia
    environment:
      HUGGING_FACE_HUB_TOKEN: ${HF_TOKEN:-}
    ports:
      - "8000:8000"
    volumes:
      - vllm-cache:/root/.cache/huggingface
```

#### 方案 B：Ollama（CPU / Apple Silicon 可跑，开发期默认）

```yaml
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama-data:/root/.ollama
```

启动后拉模型：

```bash
docker compose -f infra/docker/docker-compose.local.yml exec ollama \
  ollama pull qwen2.5:7b-instruct
```

Ollama 兼容 OpenAI API，端点为 `http://localhost:11434/v1`，模型名 `qwen2.5:7b-instruct`。

`.env` 对应：

```bash
LLM_BASE_URL=http://localhost:11434/v1
LLM_MODEL=qwen2.5:7b-instruct
LLM_API_KEY=ollama
```

#### 校验

```bash
curl http://localhost:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen2.5:7b-instruct","messages":[{"role":"user","content":"ping"}]}'
```

### 2.4 可观测性（建议）

把 pilot compose 里的 prometheus / grafana / loki 拷一份到 local compose：

```yaml
  prometheus:
    image: prom/prometheus:v3.0.1
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro

  grafana:
    image: grafana/grafana:11.4.0
    ports:
      - "3001:3000"
    volumes:
      - grafana-data:/var/lib/grafana
```

[infra/docker/prometheus.yml](../../../infra/docker/prometheus.yml) 中需要新增对 API/Jobs 的抓取 target。本机直跑时：

```yaml
scrape_configs:
  - job_name: api
    static_configs:
      - targets: ["host.docker.internal:8080"]
  - job_name: jobs
    static_configs:
      - targets: ["host.docker.internal:8090"]
```

---

## 3. 应用侧接入步骤（按依赖顺序）

> 这些是后续提交里要逐个落地的事，写到 plan 里防止遗漏。每一步都建议先补一个失败测试再实现（TDD）。

### Step A：API/Jobs 读 .env

- 新增 `services/api/internal/config/config.go`，用 `envconfig` 或 `viper` 读取 `POSTGRES_DSN`、`REDIS_ADDR`、`S3_*`、`LIVEKIT_*`、`ASR_*`、`LLM_*`
- `services/jobs` 同样
- main.go 启动时打印一份脱敏后的配置摘要，便于排错

### Step B：PostgreSQL schema 与 migration

- 引入 `goose`，建立 `services/api/db/migrations/`
- `0001_init.sql`：`meetings`、`users`、`participants`、`assets`、`jobs`
- Makefile 增加 `make migrate-up` / `make migrate-down`
- 替换 [services/api/internal/service/meeting_service.go](../../../services/api/internal/service/meeting_service.go) 里的内存 mock 为 sqlc 仓储

### Step C：Redis + Asynq 队列

- `services/jobs` 改造为 Asynq worker，监听 `post_meeting`、`asr`、`summary` 三类任务
- API 在 `/webhooks/livekit` 收到 `egress_ended` 时 enqueue `post_meeting`
- 增加 Asynqmon（http://localhost:8081）便于看任务队列

### Step D：MinIO/S3 storage adapter

- `packages` 或 `services/api/internal/storage/` 新增 S3 client（aws-sdk-go-v2）
- 实现录制文件 / 转写 / 纪要 / 导出的统一前缀与 ACL
- jobs 侧将 `WriteArtifacts` 接到真实 S3

### Step E：LiveKit 接入

- API 增加 `POST /api/meetings/:id/join` 返回 access token（用 `livekit-server-sdk-go`）
- Web 用 `livekit-client` 加入房间
- 配置 egress：在 webhook 收到房间结束后，触发 composite egress 上传到 MinIO（或在房间创建时直接开启 auto egress）

### Step F：ASR

- jobs 侧 `services/jobs/internal/services/asr.go` 由 mock 改为 HTTP 调用 `ASR_BASE_URL`
- 输入：S3 上的录制音轨；先用 ffmpeg 抽 16k mono PCM
- 输出：带时间戳的转写片段，写入 PostgreSQL `transcripts` 表 + S3

### Step G：LLM

- `services/jobs/internal/services/summarizer.go` 改为 OpenAI 兼容客户端
- Prompt 模板放 `config/prompts/`，包含摘要、待办、决议三个 chain
- 输出写 `summaries` 表 + Markdown 导出到 S3

### Step H：可观测性

- API/Jobs 暴露 Prometheus metrics（请求数、延迟直方图、队列深度、ASR/LLM 耗时）
- 接 Loki：用 Promtail 或 docker driver

---

## 4. 启动顺序（端到端调试 cheatsheet）

```bash
# 1. 起中间件
docker compose --env-file .env -f infra/docker/docker-compose.local.yml up -d

# 2. 等 healthy
docker compose -f infra/docker/docker-compose.local.yml ps

# 3. 初始化（仅首次）
make minio-bootstrap   # 待新增：建 bucket + 设置策略
make migrate-up        # 待新增：跑 goose
make ollama-pull       # 待新增：拉 LLM 模型

# 4. 起应用
make dev-api &     # services/api
make dev-jobs &    # services/jobs
make dev-web       # apps/web
```

### 健康检查清单

| 项 | 命令 | 期望 |
| --- | --- | --- |
| API | `curl localhost:8080/healthz` | `{"status":"ok"}` |
| Metrics | `curl localhost:8080/metrics` | 含 `app_up 1` |
| Web | 浏览器打开 `localhost:3000` | 试点控制台渲染 |
| Postgres | `psql $POSTGRES_DSN -c '\dt'` | 列出 migration 后的表 |
| Redis | `redis-cli ping` | `PONG` |
| MinIO | `curl localhost:9000/minio/health/live` | 200 |
| LiveKit | `curl localhost:7880` | 健康响应 |
| ASR | `curl -F audio_file=@sample.wav localhost:9001/asr` | 返回转写 |
| LLM | `curl localhost:11434/v1/models` | 模型列表 |

---

## 5. 常见问题速查

- **LiveKit webhook 收不到**：API 跑在宿主机时把 [infra/docker/livekit.yaml](../../../infra/docker/livekit.yaml) 的 webhook url 改成 `host.docker.internal:8080`，并 `docker compose restart livekit`。
- **MinIO 写入 403**：bucket 没建或没给 `meeting-assets` 写权限；用 mc 重跑 bootstrap。
- **FunASR 长时间没起来**：首次下载模型 ≈ 2 GB，盯 `docker logs -f asr`，确认进度后再 curl。
- **Ollama 第一次请求超时**：模型加载到内存约 30s–60s，先 `ollama run qwen2.5:7b-instruct ""` 预热。
- **Apple Silicon 跑 vLLM 失败**：vLLM 不支持 mps，必须切到 Ollama 方案。
- **端口冲突**：postgres 5432、redis 6379、minio 9000 在 macOS 上常被本机服务占用，必要时改 compose 端口映射并同步 `.env`。

---

## 6. 后续任务（建议拆 PR）

- [ ] feat(infra): 在 local compose 中加入 asr、ollama、prometheus、grafana
- [ ] feat(infra): 新增 `make minio-bootstrap` / `make migrate-up` / `make ollama-pull`
- [ ] feat(api): 引入 envconfig 与启动期配置打印
- [ ] feat(api): 引入 goose + 0001 init migration + sqlc 代码生成
- [ ] feat(api): 替换 meeting 内存 mock 为 Postgres 仓储
- [ ] feat(api): LiveKit join token & egress 启动接入
- [ ] feat(jobs): Asynq worker + 三类任务定义
- [ ] feat(jobs): 真实 ASR HTTP 客户端 + ffmpeg 预处理
- [ ] feat(jobs): OpenAI 兼容 LLM 客户端 + 摘要 prompt 模板
- [ ] feat(observability): Prometheus 抓取规则 + Grafana 看板 JSON
- [ ] docs: 更新 [docs/deployment.md](../../deployment.md) 把 ASR/LLM/可观测加入本地链路

## Self-review

- 中间件清单覆盖 product-definition / system-architecture 中提到的全部依赖。
- 同时给出 CPU/Apple Silicon 友好的方案 B（Whisper + Ollama），保证手头无 GPU 也能跑 E2E。
- 启动顺序与端口与现有 `.env.example` 一致，避免漂移。
- 后续任务按依赖顺序拆分，可逐个独立 PR 提交。
