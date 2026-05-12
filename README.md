# AI Meeting

面向中小企业的私有化 AI 会议产品定义仓库。

核心定位：

- 私有化部署的会议与纪要系统
- 数据主权优先，录音、录像、转写、纪要不出客户域
- 以 AI 纪要、检索、归档与系统集成为首发价值

当前仓库包含：

- `apps/web`：Next.js Web 端，当前使用 mock 数据，可直接运行查看试点控制台
- `services/api`：Go 控制面 API，当前提供 mock 会议、搜索、导出、LiveKit webhook、metrics
- `services/jobs`：Go 会后处理任务，当前提供 mock 转写、摘要、待办和存储写入
- `packages/contracts`：前后端共享契约草案
- `infra/docker`：本地与试点 Docker Compose、中间件配置、Prometheus 和 Loki 配置
- `config`：存储、身份、OA/日历、ASR/LLM 配置样例
- `discuss.md`：原始想法记录
- `docs/concept-and-stack.md`：产品构想收敛与 Go 技术栈决策
- `docs/product-definition.md`：v1 产品定义与范围收敛
- `docs/system-architecture.md`：技术架构与外部依赖边界
- `docs/interfaces.md`：首批外部接口与契约草案
- `docs/roadmap.md`：分阶段实施路线图
- `docs/validation.md`：产品与商业验证标准
- `docs/superpowers/plans/2026-04-20-ai-meeting-mvp.md`：按 superpowers 约定编写的 Go 版 MVP 实施计划

建议启动顺序：

1. 先确认 `docs/product-definition.md` 中的范围收敛是否符合目标客户。
2. 再阅读 `docs/concept-and-stack.md`，确认 Go 后端、RTC、ASR、LLM 和部署方式。
3. 最后按 `docs/superpowers/plans/2026-04-20-ai-meeting-mvp.md` 或 `docs/roadmap.md` 启动实施。

## 当前开发启动

安装依赖并运行验证：

```bash
cd apps/web && npm install
cd ../..
make test
make build-web
```

启动 Web：

```bash
make dev-web
```

启动 API：

```bash
make dev-api
```

启动本地中间件：

```bash
docker compose --env-file .env.example -f infra/docker/docker-compose.local.yml up -d
```

更多部署与运维说明见 `docs/deployment.md` 和 `docs/operations.md`。
