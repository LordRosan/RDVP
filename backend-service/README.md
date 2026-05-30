# RDVP 后端服务

RDVP 后端服务提供认证、设备档案查询、二维码防伪校验、设备档案变更审核、故障报告、维修接取、维修报告、复检和审计日志查询等 HTTP API 边界。

当前实现使用内存型基础设施适配器，服务于本地开发和 API 工作流验证。代码保持领域规则、应用编排和基础设施适配的边界清晰，后续可将存储适配器替换为真实数据库实现。

## 命令

在仓库根目录执行：

```bash
npm install
npm run backend:build
npm run backend:test
npm run backend:start
```

服务默认监听 `3000` 端口，可通过 `PORT` 环境变量调整。

## 本地账号

内置本地账号用于开发验证，密码均为 `password`。

| 用户名 | 角色 |
| --- | --- |
| `admin` | `SYSTEM_ADMIN` |
| `verifier` | `VERIFIER` |
| `deviceadmin` | `DEVICE_ADMIN` |
| `reporter` | `FAULT_REPORTER` |
| `maintainer` | `MAINTAINER` |
| `reinspector` | `REINSPECTOR` |

## API 边界

API 路径前缀为 `/api/v1`。响应结构遵循项目统一格式：

```json
{
  "success": true,
  "data": {},
  "requestId": "req_local",
  "timestamp": "2026-05-29T00:00:00.000Z"
}
```
