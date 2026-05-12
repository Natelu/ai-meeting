# 部署说明

## 本地 mock 开发

1. 安装 Go 1.23 和 Node.js 22。
2. 复制 `.env.example` 为 `.env`，按需调整端口和密钥。
3. 启动中间件：

```bash
docker compose --env-file .env.example -f infra/docker/docker-compose.local.yml up -d
```

4. 启动 API：

```bash
cd services/api
API_ADDR=:8080 go run ./cmd/api
```

5. 启动 Web：

```bash
cd apps/web
npm install
npm run dev
```

Web 默认地址是 `http://localhost:3000`，API 默认地址是 `http://localhost:8080`。

## 试点部署

1. 准备一台已安装 Docker 和 Docker Compose 的 Linux 主机。
2. 准备客户域内的对象存储或 NAS；本仓库默认先用 MinIO mock。
3. 基于 `.env.example` 创建 `.env`，替换 Postgres、Redis、LiveKit、S3、ASR、LLM 配置。
4. 构建并启动试点栈：

```bash
docker compose --env-file .env -f infra/docker/docker-compose.pilot.yml up -d --build
```

5. 验证以下端点：

```bash
curl http://localhost/healthz
curl http://localhost/api/meetings
curl http://localhost/metrics
```

## 对接顺序建议

1. 先接 PostgreSQL 和 Redis，替换内存 mock 与任务状态 mock。
2. 再接 MinIO 或客户 S3，确认录制、转写和纪要写入路径。
3. 接 LiveKit 房间创建、加入 token 和 egress webhook。
4. 接 ASR 服务，输出标准转写片段。
5. 接 LLM OpenAI-compatible API，输出摘要和待办。
6. 接企业身份、OA 或日历系统。
