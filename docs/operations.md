# 运维手册

## 核心健康检查

- Web：`GET /`
- API：`GET /healthz`
- Metrics：`GET /metrics`
- PostgreSQL：`pg_isready`
- Redis：`redis-cli ping`
- MinIO：`mc ready local`
- LiveKit：容器日志中无 room/rtc 错误

## 关键监控项

- `app_up`：API 是否可被 Prometheus 抓取
- 会议创建成功率
- LiveKit webhook 接收数量和失败数量
- 会后任务排队时长、处理时长、失败数量
- 存储写入失败数量
- 回放、导出和权限变更审计数量

## 日常排障

1. Web 无法打开：检查 `web` 容器、Nginx upstream 和 `NEXT_PUBLIC_API_BASE_URL`。
2. API 不通：检查 `api` 容器日志和 `/healthz`。
3. 录制事件不触发：检查 `infra/docker/livekit.yaml` 的 webhook URL、API key 和网络连通性。
4. 资产未归档：检查 S3/NAS 配置、bucket 权限和 jobs 容器日志。
5. 纪要为空：检查 ASR 输出，再检查 LLM endpoint、model 和 API key。

## 数据边界

- 控制面数据写入 PostgreSQL。
- 内容数据写入 S3 或 NAS。
- ASR 和 LLM 默认应部署在客户域内；如使用外部模型服务，需要在合同和配置中明确数据流向。
