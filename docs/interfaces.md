# 外部接口与契约草案

本文件定义 v1 必须预留的集成边界，目的是减少后续返工，而不是一次性设计完整开放平台。

## 1. Storage Adapter

目标：

- 将录音、录像、转写、纪要输出到客户指定位置

首发支持：

- S3 兼容对象存储
- NAS 挂载目录

最小配置字段：

```json
{
  "type": "s3",
  "bucket": "meeting-assets",
  "region": "cn-example-1",
  "endpoint": "https://s3.example.local",
  "accessKeyId": "******",
  "secretAccessKey": "******",
  "prefix": "tenant-a/"
}
```

NAS 模式最小配置：

```json
{
  "type": "nas",
  "mountPath": "/mnt/customer-meeting-assets",
  "prefix": "tenant-a/"
}
```

统一能力要求：

- 上传原始录音和录像
- 上传转写文本与纪要结果
- 支持按租户和会议 ID 组织目录
- 写入失败可重试并可追踪

## 2. Identity Adapter

目标：

- 将用户身份与组织关系接入企业现有体系

v1 预留能力：

- 外部用户唯一标识映射
- 组织与部门同步入口
- 登录后角色映射

建议最小接口语义：

- `resolveUser`
- `resolveGroups`
- `mapRoles`

不在 v1 强制实现：

- 全量 SCIM
- 复杂动态授权策略

## 3. Calendar / OA Adapter

目标：

- 将会议创建、会邀、会议链接分发接入客户现有系统

v1 预留能力：

- 外部系统创建会议
- 外部系统更新会议时间和参会人
- 外部系统取消会议

建议事件模型：

```json
{
  "eventType": "meeting.created",
  "externalEventId": "oa-123456",
  "title": "周会",
  "startTime": "2026-04-21T10:00:00+08:00",
  "endTime": "2026-04-21T11:00:00+08:00",
  "participants": [
    {
      "externalUserId": "u-001",
      "role": "host"
    }
  ]
}
```

## 4. Document Export

目标：

- 将纪要、转写、待办稳定导出与归档

v1 输出格式：

- Markdown
- JSON
- PDF

统一导出结构：

- 会议基础信息
- 纪要摘要
- 待办列表
- 发言人转写片段
- 附件与录制链接引用

## 5. Search Contract

目标：

- 支持面向会议历史的可控检索

v1 查询条件：

- 会议名称
- 时间范围
- 发言人
- 关键词
- 标签或主题

v1 返回结果：

- 命中的会议
- 摘要片段
- 发言人片段
- 可访问的回放与纪要链接

## 接口设计原则

- 先定义稳定边界，再扩展实现深度
- 所有外部集成都必须支持禁用与替换
- 若客户不提供外部系统，也能独立完成会议、纪要与归档主流程
