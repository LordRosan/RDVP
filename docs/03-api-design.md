# RDVP API 设计

## 文档信息

| 项目 | 内容 |
| --- | --- |
| 项目名称 | RDVP |
| 文档名称 | API 设计 |
| 文档版本 | v0.1 |
| 文档状态 | 草案 |
| 创建日期 | 2026-05-27 |

## 1. 设计范围

本文档定义 RDVP 后端服务对移动端应用提供的 HTTP API。当前已实现接口覆盖用户认证、设备档案查询、二维码校验、设备核验、设备档案申请、故障报修、维修任务、维修报告、复检报告、档案审核、运维审核、日志查询和底层日志条目等业务。附件、离线同步和通知接口为后续增强预留，不属于当前可调用 API。

API 采用版本化路径，第一版统一使用：

```text
/api/v1
```

健康检查接口不使用业务前缀：

```text
GET /healthz
GET /readyz
```

健康检查接口用于部署平台、反向代理或监控系统判断服务存活与就绪状态，不需要登录认证。

## 2. 通用约定

### 2.1 协议

- 所有业务接口使用 HTTPS。
- 请求和响应主体使用 JSON。
- 文件上传使用 `multipart/form-data`。
- 字符编码使用 UTF-8。

### 2.2 字段命名

- API JSON 字段使用 lowerCamelCase。
- 枚举值使用 UPPER_SNAKE_CASE。
- 数据库字段命名在数据库设计文档中单独定义。

### 2.3 时间格式

时间字段使用 ISO 8601 格式。

示例：

```text
2026-05-27T07:30:00Z
```

客户端负责按用户所在时区展示时间。

### 2.4 标识符

- 系统内部主键在 API 中统一表示为字符串。
- 设备业务编号使用 `deviceCode`。
- 报告、任务、申请等业务对象可以同时具备内部 `id` 和业务编号，例如 `faultReportNo`。

### 2.5 请求头

| Header | 必填 | 说明 |
| --- | --- | --- |
| `Authorization` | 登录后必填 | 访问凭证，格式为 `Bearer <token>` |
| `Content-Type` | 是 | 请求内容类型 |
| `X-Request-Id` | 否 | 客户端请求标识，用于链路追踪和幂等排查 |
| `X-Client-Version` | 否 | 移动端版本 |
| `X-Device-Id` | 否 | 移动端安装实例或设备标识 |

## 3. 通用响应结构

### 3.1 成功响应

```json
{
  "success": true,
  "data": {},
  "requestId": "req_202605270001",
  "timestamp": "2026-05-27T07:30:00Z"
}
```

### 3.2 失败响应

```json
{
  "success": false,
  "error": {
    "code": "DEVICE_NOT_FOUND",
    "message": "Device not found.",
    "details": {}
  },
  "requestId": "req_202605270001",
  "timestamp": "2026-05-27T07:30:00Z"
}
```

### 3.3 分页响应

```json
{
  "success": true,
  "data": {
    "items": [],
    "page": 1,
    "pageSize": 20,
    "total": 0
  },
  "requestId": "req_202605270001",
  "timestamp": "2026-05-27T07:30:00Z"
}
```

分页参数：

| 参数 | 说明 |
| --- | --- |
| `page` | 页码，从 1 开始 |
| `pageSize` | 每页数量 |
| `sortBy` | 排序字段 |
| `sortOrder` | 排序方向，`ASC` 或 `DESC` |

## 4. 通用错误码

| 错误码 | HTTP 状态码 | 说明 |
| --- | --- | --- |
| `BAD_REQUEST` | 400 | 请求参数错误 |
| `UNAUTHORIZED` | 401 | 未登录或访问凭证无效 |
| `FORBIDDEN` | 403 | 当前用户无权限执行该操作 |
| `NOT_FOUND` | 404 | 资源不存在 |
| `CONFLICT` | 409 | 资源状态冲突 |
| `VALIDATION_FAILED` | 422 | 业务校验失败 |
| `RATE_LIMITED` | 429 | 请求频率超过限制 |
| `INTERNAL_ERROR` | 500 | 服务端内部错误 |

## 5. 认证接口

### 5.1 用户登录

```text
POST /api/v1/auth/login
```

请求体：

```json
{
  "username": "user001",
  "password": "password",
  "clientDeviceId": "mobile-device-id"
}
```

响应数据：

```json
{
  "accessToken": "opaque-token",
  "expiresIn": 604800,
  "user": {
    "id": "user-id",
    "username": "user001",
    "displayName": "User Name",
    "roles": ["MAINTAINER"],
    "permissions": ["ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY", "OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT"]
  }
}
```

账号不存在或不可用时返回 `ACCOUNT_INCORRECT`；密码不正确时返回 `PASSWORD_INCORRECT`；同一账号连续密码错误达到限制后返回 `RATE_LIMITED`。

### 5.2 当前用户信息

```text
GET /api/v1/auth/me
```

响应数据：

```json
{
  "id": "user-id",
  "username": "user001",
  "displayName": "User Name",
  "roles": ["MAINTAINER"],
  "permissions": ["ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY", "OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT"]
}
```

### 5.3 当前用户密码校验

```text
POST /api/v1/auth/password-verification
```

权限要求：登录用户。

该接口用于删除档案等敏感操作前的二次校验。校验当前登录用户的密码，不创建新的登录会话。

请求体：

```json
{
  "password": "password"
}
```

响应数据：

```json
{
  "verified": true
}
```

校验失败时返回 `PASSWORD_INCORRECT`；连续失败达到限制后返回 `PASSWORD_VERIFICATION_LOCKED`。

### 5.4 退出登录

```text
POST /api/v1/auth/logout
```

响应数据：

```json
{
  "loggedOut": true
}
```

### 5.5 主页数据看板

```text
GET /api/v1/home/dashboard
```

权限要求：登录用户。服务端会按当前用户权限裁剪响应字段。

该接口为移动端首页数据看板提供真实业务统计，不返回后端服务状态、认证状态或旧版概览数据。用户无权查看的中心或字段会从响应中省略，客户端不得用 `0` 或占位内容补出未返回的数据。

响应数据：

```json
{
  "archive": {
    "deviceTotal": 3,
    "archiveCreates": 1,
    "archiveDeletes": 0,
    "archiveUpdates": 2,
    "archiveQueries": 8,
    "archiveExports": 1
  },
  "operations": {
    "taskPoolTotal": 4,
    "verifications": 12,
    "faultReports": 3,
    "repairs": 2,
    "reinspections": 1
  },
  "review": {
    "reviewedTotal": 5,
    "pendingArchiveReviews": 1,
    "pendingOperationsReviews": 0
  },
  "log": {
    "logTotal": 18,
    "archiveOperationLogs": 6,
    "archiveReviewLogs": 4,
    "operationsOperationLogs": 5,
    "operationsReviewLogs": 3
  }
}
```

统计口径：

| 字段 | 口径 |
| --- | --- |
| `archive.deviceTotal` | 当前未删除设备档案总量 |
| `archive.archiveCreates` | 已审核通过的新增档案申请数 |
| `archive.archiveDeletes` | 已审核通过的删除档案申请数 |
| `archive.archiveUpdates` | 已审核通过的修改档案申请数 |
| `archive.archiveQueries` | 成功查询设备档案的日志数 |
| `archive.archiveExports` | 成功导出设备二维码的日志数 |
| `operations.taskPoolTotal` | 当前任务池中的维修任务与复检任务总数 |
| `operations.verifications` | 设备核验报告总数 |
| `operations.faultReports` | 故障报修记录总数 |
| `operations.repairs` | 已提交维修报告总数 |
| `operations.reinspections` | 已提交复检报告总数 |
| `review.reviewedTotal` | 已完成审核的档案申请和运维审核总数 |
| `review.pendingArchiveReviews` | 档案审核中的待审核申请数 |
| `review.pendingOperationsReviews` | 运维审核中的待审核数 |
| `log.logTotal` | 当前用户可见日志分类数量之和 |
| `log.archiveOperationLogs` | 档案操作日志数量 |
| `log.archiveReviewLogs` | 档案审核日志数量 |
| `log.operationsOperationLogs` | 运维操作日志数量 |
| `log.operationsReviewLogs` | 运维审核日志数量 |

权限裁剪：

| 数据 | 可见条件 |
| --- | --- |
| `archive` | 具备档案新增、修改、删除或二维码导出等档案业务权限 |
| `operations` | 具备核验、报修、维修任务、维修报告、复检任务或复检报告等运维业务权限 |
| `review.reviewedTotal` | 具备审核日志查询权限 |
| `review.pendingArchiveReviews` | 具备档案申请审核权限 |
| `review.pendingOperationsReviews` | 具备运维审核权限 |
| `log.archiveOperationLogs` | 具备档案操作日志查询权限 |
| `log.archiveReviewLogs` | 具备档案审核日志查询权限 |
| `log.operationsOperationLogs` | 具备运维操作日志查询权限 |
| `log.operationsReviewLogs` | 具备运维审核日志查询权限 |

典型角色可见范围：

| 角色 | 可见范围 |
| --- | --- |
| 超级管理员 | 全部中心和全部字段 |
| 档案管理员 | 档案中心全部数据、审核中心的档案审核待审核数 |
| 档案员 | 档案中心全部数据 |
| 运维管理员 | 运维中心全部数据、审核中心的运维审核待审核数 |
| 运维员 | 运维中心全部数据 |
| 普通管理员 | 审核中心和日志中心全部数据 |

## 6. 设备接口

### 6.1 通过设备编号查询设备

```text
GET /api/v1/devices/by-code/{deviceCode}
```

权限要求：`ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY`

当前设备编号格式：

```text
RDVP-DEVICE-0001
```

响应数据：

```json
{
  "id": "device-id",
  "deviceCode": "RDVP-DEVICE-0001",
  "name": "Device Name",
  "model": "Model A",
  "manufacturer": "Manufacturer",
  "location": {
    "address": "Device address",
    "longitude": 114.1694,
    "latitude": 22.3193
  },
  "status": "NORMAL",
  "lastVerificationTime": "2026-05-27T07:30:00Z",
  "archiveRequestState": {
    "locked": false,
    "pendingRequestId": null,
    "freezeUntil": null
  }
}
```

### 6.2 获取设备详情

```text
GET /api/v1/devices/{deviceId}
```

权限要求：`ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY`

响应数据：

```json
{
  "id": "device-id",
  "deviceCode": "RDVP-DEVICE-0001",
  "name": "Device Name",
  "model": "Model A",
  "manufacturer": "Manufacturer",
  "location": {
    "address": "Device address",
    "longitude": 114.1694,
    "latitude": 22.3193
  },
  "status": "NORMAL",
  "lastVerificationTime": "2026-05-27T07:30:00Z",
  "archiveRequestState": {
    "locked": false,
    "pendingRequestId": null,
    "freezeUntil": null
  },
  "recentFaultReports": [],
  "recentRepairReports": [],
  "recentVerificationReports": []
}
```

### 6.3 校验设备编号可用性

```text
GET /api/v1/device-codes/{deviceCode}/availability
```

权限要求：`ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT`

该接口用于添加设备档案申请前校验目标设备编号是否已被正式档案或待审核添加申请占用。

响应数据：

```json
{
  "available": true,
  "reason": "设备编号可用于添加档案"
}
```

当前后端未开放独立的设备列表分页查询接口；业务列表查询通过日志查询、任务接取和审核列表等专用接口完成。

## 7. 二维码接口

### 7.1 校验二维码并查询设备

```text
POST /api/v1/device-qrcodes/verify
```

权限要求：`ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY`

二维码内容格式：

```text
RDVP:<version>:<deviceCode>:<nonce>:<signature>
```

`signature` 使用 HMAC-SHA256 计算，签名原文为 `<version>:<deviceCode>:<nonce>`。服务端会同时校验设备编号、随机标识、二维码状态、过期时间和签名摘要。

请求体：

```json
{
  "qrContent": "RDVP:1:RDVP-DEVICE-0001:nonce:signature"
}
```

响应数据：

```json
{
  "valid": true,
  "device": {
    "id": "device-id",
    "deviceCode": "RDVP-DEVICE-0001",
    "name": "Device Name",
    "status": "NORMAL"
  }
}
```

二维码校验失败时返回 `QR_CODE_INVALID`、`QR_CODE_EXPIRED` 或 `QR_CODE_SIGNATURE_INVALID`。

### 7.2 导出设备二维码

```text
POST /api/v1/devices/{deviceId}/qrcode-export
```

权限要求：`ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY` 和 `ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT`。提交前必须完成当前用户密码校验。

响应数据：

```json
{
  "deviceId": "device-id",
  "deviceCode": "RDVP-DEVICE-0001",
  "fileName": "RDVP-DEVICE-0001-qrcode.png",
  "qrImageBase64": "base64-encoded-png",
  "qrContentDigest": "sha256-digest",
  "exportedAt": "2026-05-27T07:30:00Z"
}
```

### 7.3 校验档案导出权限

```text
POST /api/v1/devices/{deviceId}/archive-export-verification
```

权限要求：`ARCHIVE_CENTER_DEVICE_ARCHIVE_QUERY` 和 `ARCHIVE_CENTER_DEVICE_ARCHIVE_EXPORT`。提交前必须完成当前用户密码校验。

响应数据：

```json
{
  "verified": true,
  "deviceId": "device-id",
  "deviceCode": "RDVP-DEVICE-0001"
}
```

## 8. 设备核验接口

### 8.1 提交设备核验报告

```text
POST /api/v1/devices/{deviceId}/verification-reports
```

请求体：

```json
{
  "result": "NORMAL",
  "description": "Device is operating normally.",
  "remark": "No abnormal noise.",
  "verifiedAt": "2026-05-27T07:30:00Z"
}
```

响应数据：

```json
{
  "id": "verification-record-id",
  "deviceId": "device-id",
  "operatorId": "user-id",
  "result": "NORMAL",
  "description": "Device is operating normally.",
  "remark": "No abnormal noise.",
  "verifiedAt": "2026-05-27T07:30:00Z",
  "createdAt": "2026-05-27T07:30:00Z"
}
```

提交设备核验报告前必须完成当前用户密码校验。

### 8.2 提交设备核验并联动报修

```text
POST /api/v1/devices/{deviceId}/verification-reports/fault-report
```

权限要求：`OPERATIONS_CENTER_DEVICE_VERIFICATION_SUBMIT` 和 `OPERATIONS_CENTER_DEVICE_FAULT_REPORT_SUBMIT`。提交前必须完成当前用户密码校验。

请求体：

```json
{
  "result": "ABNORMAL",
  "description": "Device temperature is abnormal.",
  "remark": "Need follow-up repair.",
  "verifiedAt": "2026-05-27T07:20:00Z",
  "faultType": "ENERGY_FAULT",
  "severity": "SEVERE",
  "occurredAt": "2026-05-27T07:30:00Z",
  "faultDescription": "Device power supply is unstable.",
  "sceneCondition": "The site has reduced the operating load.",
  "longitude": 114.1694,
  "latitude": 22.3193
}
```

响应数据：

```json
{
  "verificationReport": {
    "id": "verification-record-id",
    "deviceId": "device-id",
    "operatorId": "user-id",
    "result": "ABNORMAL",
    "description": "Device temperature is abnormal.",
    "remark": "Need follow-up repair.",
    "verifiedAt": "2026-05-27T07:20:00Z",
    "createdAt": "2026-05-27T07:30:00Z"
  },
  "faultReport": {
    "id": "fault-report-id",
    "faultReportNo": "FR-20260527-0001",
    "status": "PENDING_ACCEPTANCE",
    "createdAt": "2026-05-27T07:30:00Z"
  }
}
```

## 9. 设备档案申请接口

### 9.1 创建设备档案申请

```text
POST /api/v1/device-archive-requests
```

修改档案请求体：

```json
{
  "type": "UPDATE",
  "deviceId": "device-id",
  "reason": "Location information is outdated.",
  "changes": {
    "location.address": {
      "oldValue": "Old address",
      "newValue": "New address"
    }
  }
}
```

添加档案请求体：

```json
{
  "type": "CREATE",
  "deviceCode": "RDVP-DEVICE-0099",
  "reason": "New device installation.",
  "changes": {
    "name": {
      "newValue": "Inspection Gateway G-99"
    },
    "model": {
      "newValue": "IG-900"
    },
    "manufacturer": {
      "newValue": "North Equipment"
    },
    "location.address": {
      "newValue": "Plant 9 Inspection Area"
    }
  }
}
```

删除档案请求体：

```json
{
  "type": "DELETE",
  "deviceId": "device-id",
  "reason": "Device retired."
}
```

权限要求：

| 申请类型 | 权限 |
| --- | --- |
| `UPDATE` | `ARCHIVE_CENTER_DEVICE_ARCHIVE_UPDATE_REQUEST_SUBMIT` |
| `CREATE` | `ARCHIVE_CENTER_DEVICE_ARCHIVE_CREATE_REQUEST_SUBMIT` |
| `DELETE` | `ARCHIVE_CENTER_DEVICE_ARCHIVE_DELETE_REQUEST_SUBMIT` |

当前可修改字段：`name`、`model`、`manufacturer`、`location.address`。设备运行状态不通过档案修改申请直接修改，应由核验、故障、维修和复检流程驱动。

后端创建申请前必须校验：

- 设备不存在待审核档案申请。
- 设备不处于档案申请冻结期。
- 提交的新值与当前设备档案存在有效差异。
- 申请中的 `oldValue` 必须与后端当前档案值一致，避免基于过期页面提交覆盖更新。
- 添加和删除档案申请在审核通过前不直接写入或删除正式档案。
- 同一设备或同一目标设备编号不存在待审核申请。

响应数据：

```json
{
  "id": "archive-request-id",
  "status": "PENDING_REVIEW",
  "createdAt": "2026-05-27T07:30:00Z"
}
```

### 9.2 查询档案申请列表

```text
GET /api/v1/device-archive-requests
```

权限要求：`REVIEW_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW`

查询参数：

| 参数 | 说明 |
| --- | --- |
| `deviceCode` | 设备编号 |
| `status` | 申请状态 |
| `applicantId` | 申请人 ID |
| `page` | 页码 |
| `pageSize` | 每页数量 |

### 9.3 审核设备档案申请

```text
POST /api/v1/device-archive-requests/{requestId}/review
```

权限要求：`REVIEW_CENTER_DEVICE_ARCHIVE_REQUEST_REVIEW`

请求体：

```json
{
  "decision": "APPROVED",
  "reviewedAt": "2026-05-27T07:30:00Z",
  "reviewComment": "Approved."
}
```

响应数据：

```json
{
  "id": "archive-request-id",
  "status": "APPROVED",
  "reviewedAt": "2026-05-27T07:30:00Z",
  "freezeUntil": "2026-05-27T13:30:00Z"
}
```

审核通过后，后端按申请类型应用档案修改、添加或删除；审核结束后（通过或驳回）设置 6 小时档案申请冻结期，冻结期从 `reviewedAt` 开始计算。审核驳回时必须保留驳回意见。

## 10. 故障报告接口

### 10.1 创建故障报告

```text
POST /api/v1/fault-reports
```

请求体：

```json
{
  "deviceCode": "RDVP-DEVICE-0001",
  "faultType": "ENERGY_FAULT",
  "severity": "SEVERE",
  "occurredAt": "2026-05-27T07:30:00Z",
  "description": "Device power supply is unstable.",
  "sceneCondition": "The site has reduced the operating load.",
  "longitude": 114.1694,
  "latitude": 22.3193
}
```

响应数据：

```json
{
  "id": "fault-report-id",
  "faultReportNo": "FR-20260527-0001",
  "status": "PENDING_ACCEPTANCE",
  "createdAt": "2026-05-27T07:30:00Z"
}
```

当前后端未开放独立的故障报告列表、详情和驳回接口。待接取故障通过 `GET /api/v1/operation-tasks/available` 查询；历史故障日志通过 `GET /api/v1/log-center/logs?category=OPERATIONS_OPERATION` 查询。

## 11. 维修任务接口

### 11.1 查询附近可接取故障

```text
GET /api/v1/operation-tasks/available
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `longitude` | 当前经度 |
| `latitude` | 当前纬度 |
| `radiusKm` | 查询半径，默认 10，允许范围 0-30；低负载状态下不能超过当前负载允许范围 |
| `severity` | 故障等级 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

响应数据应包含当前维修人员负载快照：

```json
{
  "radiusKm": 10,
  "workload": {
    "status": "LOW_LOAD",
    "activeTaskCount": 1,
    "maxActiveTaskCount": 3,
    "maxRadiusKm": 20,
    "recommendedRadiusKm": 20,
    "message": "当前已有进行中的维修任务，系统已限制可接取范围。请优先处理已接取任务。",
    "canAccept": true
  },
  "items": [],
  "total": 0
}
```

后端必须根据当前用户进行中的维修任务数判定负载状态。忙碌状态返回 `REPAIRER_BUSY`，低负载状态下超出可接取范围返回 `REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD`。

### 11.2 接取故障任务

```text
POST /api/v1/fault-reports/{faultReportId}/accept
```

请求体：

```json
{
  "longitude": 114.1694,
  "latitude": 22.3193
}
```

响应数据：

```json
{
  "repairTaskId": "repair-task-id",
  "faultReportId": "fault-report-id",
  "status": "ACCEPTED",
  "acceptedAt": "2026-05-27T07:30:00Z"
}
```

同一故障只能被一个有效维修任务接取。并发接取失败时返回 `FAULT_ALREADY_ACCEPTED`。

接取接口必须重新校验维修人员负载状态，不得只依赖查询列表时的前端状态。忙碌状态返回 `REPAIRER_BUSY`；若提供接取位置且目标故障超出当前负载允许范围，返回 `REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD`。

### 11.3 查询已接取维修任务

```text
GET /api/v1/repair-tasks/accepted
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `status` | 维修任务状态 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

## 12. 维修报告接口

### 12.1 提交维修报告

```text
POST /api/v1/repair-tasks/{repairTaskId}/repair-reports
```

请求体：

```json
{
  "result": "REPAIRED",
  "repairedAt": "2026-05-27T07:30:00Z",
  "processDescription": "Replaced the power module and completed verification.",
  "partsUsed": "Power module x1"
}
```

响应数据：

```json
{
  "id": "repair-report-id",
  "repairReportNo": "RR-20260527-0001",
  "repairTaskId": "repair-task-id",
  "faultReportId": "fault-report-id",
  "result": "REPAIRED",
  "nextStatus": "PENDING_REINSPECTION",
  "requiresReinspection": true,
  "createdAt": "2026-05-27T07:30:00Z"
}
```

## 13. 复检接口

### 13.1 查询待复检故障

```text
GET /api/v1/reinspections/pending
```

响应数据：

```json
{
  "items": [
    {
      "id": "fault-report-id",
      "faultReportId": "fault-report-id",
      "faultReportNo": "RDF-202605270001",
      "deviceCode": "RDVP-DEVICE-0001",
      "deviceName": "Cooling Pump A-01",
      "severity": "SEVERE",
      "location": {
        "address": "Plant 1 Power Area",
        "longitude": 114.1694,
        "latitude": 22.3193
      },
      "repairedAt": "2026-05-27T07:00:00Z",
      "status": "PENDING_REINSPECTION"
    }
  ],
  "total": 1
}
```

### 13.2 接取复检任务

```text
POST /api/v1/reinspections/{faultReportId}/accept
```

权限要求：`OPERATIONS_CENTER_REINSPECTION_TASK_ACCEPT`

请求体：

```json
{
  "longitude": 114.1694,
  "latitude": 22.3193
}
```

响应数据：

```json
{
  "repairTaskId": "repair-task-id",
  "faultReportId": "fault-report-id",
  "status": "ACCEPTED",
  "acceptedAt": "2026-05-27T07:30:00Z"
}
```

### 13.3 提交复检报告

```text
POST /api/v1/fault-reports/{faultReportId}/reinspection-reports
```

请求体：

```json
{
  "result": "PASSED",
  "description": "Repair result verified.",
  "reinspectedAt": "2026-05-27T07:30:00Z"
}
```

响应数据：

```json
{
  "id": "reinspection-report-id",
  "reinspectionReportNo": "RDI-202605270001",
  "faultReportId": "fault-report-id",
  "result": "PASSED",
  "nextFaultStatus": "CLOSED",
  "nextDeviceStatus": "NORMAL",
  "createdAt": "2026-05-27T07:30:00Z"
}
```

## 14. 运维审核接口

### 14.1 查询待审核操作列表

```text
GET /api/v1/operations-review-requests
```

权限要求：`REVIEW_CENTER_OPERATIONS_REVIEW`

查询参数：

| 参数 | 说明 |
| --- | --- |
| `status` | 审核状态，默认由客户端查询待审核数据 |
| `type` | 审核类型：`DEVICE_VERIFICATION_REPORT`、`FAULT_REPORT`、`REPAIR_REPORT`、`REINSPECTION_REPORT` |
| `keyword` | 设备编号、审核编号等关键词 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

响应数据：

```json
{
  "items": [
    {
      "id": "operations-review-id",
      "type": "REPAIR_REPORT",
      "targetId": "repair-report-id",
      "targetNo": "RDR-202606240001",
      "faultReportId": "fault-id",
      "deviceId": "device-id",
      "deviceCode": "RDVP-DEVICE-0001",
      "deviceName": "Cooling Pump A-01",
      "operatorId": "usr-operator",
      "operatorName": "运维员",
      "summary": "维修结果：REPAIRED；维修说明：已完成维修并复测",
      "status": "PENDING_REVIEW",
      "submittedAt": "2026-06-24T07:30:00Z"
    }
  ],
  "total": 1
}
```

### 14.2 提交运维审核报告

```text
POST /api/v1/operations-review-requests/{requestId}/review
```

权限要求：`REVIEW_CENTER_OPERATIONS_REVIEW`。提交前必须完成当前用户密码校验。

请求体：

```json
{
  "decision": "APPROVED",
  "reviewedAt": "2026-06-24T08:30:00Z",
  "reviewComment": "审核通过"
}
```

响应数据：

```json
{
  "id": "operations-review-id",
  "status": "APPROVED",
  "reviewedAt": "2026-06-24T08:30:00Z"
}
```

同一运维审核请求只能审核一次。重复审核返回 `OPERATIONS_REVIEW_REQUEST_ALREADY_REVIEWED`。

## 15. 日志查询接口

### 15.1 查询业务日志

```text
GET /api/v1/log-center/logs
```

权限要求按日志分类拆分：

| `category` | 权限要求 |
| --- | --- |
| `ARCHIVE_OPERATION` | `LOG_CENTER_ARCHIVE_OPERATION_LOG_QUERY` |
| `ARCHIVE_REVIEW` | `LOG_CENTER_ARCHIVE_REVIEW_LOG_QUERY` |
| `OPERATIONS_OPERATION` | `LOG_CENTER_OPERATIONS_OPERATION_LOG_QUERY` |
| `OPERATIONS_REVIEW` | `LOG_CENTER_OPERATIONS_REVIEW_LOG_QUERY` |

查询参数：

| 参数 | 说明 |
| --- | --- |
| `category` | 日志分类：`ARCHIVE_OPERATION`、`ARCHIVE_REVIEW`、`OPERATIONS_OPERATION`、`OPERATIONS_REVIEW` |
| `type` | 业务类型，可为空 |
| `keyword` | 设备编号、任务编号、操作人或描述关键词 |
| `page` | 页码，默认 `1` |
| `pageSize` | 每页数量，默认 `20`，最大 `100` |

响应数据：

```json
{
  "items": [
    {
      "logCategory": "OPERATIONS_REVIEW",
      "logType": "REPAIR_REPORT",
      "deviceCode": "RDVP-DEVICE-0001",
      "taskNo": "RDR-202606240001",
      "operatorName": "运维管理员",
      "occurredAt": "2026-06-24T08:30:00Z",
      "businessStatus": "APPROVED",
      "description": "Repair report accepted."
    }
  ],
  "total": 1
}
```

当 `category` 为空或不属于允许值时返回 `BAD_REQUEST`；当前用户缺少对应分类权限时返回 `FORBIDDEN`。旧 `/api/v1/management-records` 和 `/api/v1/record-center/records` 路由不再保留。

## 16. 后续预留接口

附件上传、离线批量同步和通知查询属于后续增强能力。当前后端未开放 `/api/v1/attachments`、`/api/v1/sync/offline-records` 和 `/api/v1/notifications/*` 路由；客户端不得按这些预留设计发起当前版本联调。

## 17. 底层日志条目接口

### 17.1 查询底层日志条目

```text
GET /api/v1/log-entries
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `action` | 操作类型 |
| `keyword` | 目标编号、目标 ID、操作人或描述关键词 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

响应数据：

```json
{
  "items": [
    {
      "id": "log-entry-id",
      "action": "FAULT_REPORT",
      "targetId": "fault-report-id",
      "targetNo": "FR-20260527-0001",
      "actorId": "user-id",
      "actorName": "User Name",
      "status": "SUCCESS",
      "description": "Created fault report.",
      "occurredAt": "2026-05-27T07:30:00Z"
    }
  ],
  "page": 1,
  "pageSize": 20,
  "total": 1
}
```

## 18. 枚举定义

### 18.1 设备状态

```text
NORMAL
PENDING_VERIFICATION
ARCHIVE_REQUEST_PENDING_REVIEW
FAULTED
UNDER_REPAIR
PENDING_REINSPECTION
DISABLED
RETIRED
```

### 18.2 设备档案申请状态

```text
PENDING_REVIEW
APPROVED
REJECTED
WITHDRAWN
```

### 18.3 故障报告状态

```text
SUBMITTED
PENDING_ACCEPTANCE
ACCEPTED
UNDER_REPAIR
REPAIR_COMPLETED
PENDING_REINSPECTION
CLOSED
REJECTED
```

### 18.4 故障类型

```text
OPERATION_ABNORMAL
HARDWARE_DAMAGE
COMMUNICATION_FAULT
LOGIC_FAULT
ENERGY_FAULT
EXTERNAL_FACTOR
OTHER
```

### 18.5 故障等级

```text
EMERGENCY
SEVERE
GENERAL
MINOR
```

### 18.6 维修任务状态

```text
AVAILABLE
ACCEPTED
PROCESSING
REPORT_SUBMITTED
```

### 18.7 维修报告结果

```text
REPAIRED
TEMPORARY_RESTORED
UNRESOLVED
```

### 18.8 复检结果

```text
PASSED
FAILED
```

### 18.9 日志状态

```text
SUCCESS
FAILED
```

### 18.10 后续预留离线记录类型

以下枚举仅用于后续离线同步设计，当前版本未开放离线同步接口：

```text
VERIFICATION_RECORD
DEVICE_ARCHIVE_REQUEST
FAULT_REPORT
REPAIR_REPORT
REINSPECTION_REPORT
```

## 19. 业务错误码

| 错误码 | 说明 |
| --- | --- |
| `DEVICE_NOT_FOUND` | 设备不存在 |
| `DEVICE_CODE_INVALID` | 设备编号格式无效 |
| `QR_CODE_INVALID` | 二维码内容无效 |
| `QR_CODE_EXPIRED` | 二维码已过期 |
| `QR_CODE_SIGNATURE_INVALID` | 二维码签名校验失败 |
| `DEVICE_ARCHIVE_REQUEST_LOCKED` | 设备存在待审核档案申请 |
| `DEVICE_ARCHIVE_REQUEST_FROZEN` | 设备处于档案申请冻结期 |
| `DEVICE_ARCHIVE_REQUEST_NOT_FOUND` | 设备档案申请不存在 |
| `DEVICE_ARCHIVE_REQUEST_ALREADY_REVIEWED` | 设备档案申请已审核 |
| `FAULT_REPORT_NOT_FOUND` | 故障报告不存在 |
| `FAULT_ALREADY_ACCEPTED` | 故障已被其他维修人员接取 |
| `REPAIR_REPORT_INVALID` | 维修报告内容无效 |
| `REPAIR_REPORT_NOT_FOUND` | 维修报告不存在 |
| `REPAIR_TASK_NOT_FOUND` | 维修任务不存在 |
| `REPAIR_TASK_STATUS_INVALID` | 维修任务状态不允许当前操作 |
| `REPAIR_TASK_RADIUS_INVALID` | 维修任务查询范围无效 |
| `REPAIR_TASK_RADIUS_EXCEEDS_WORKLOAD` | 查询范围超过当前负载允许范围 |
| `REPAIRER_BUSY` | 维修人员当前忙碌，不能接取更多任务 |
| `REINSPECTION_REPORT_INVALID` | 复检报告内容无效 |
| `REINSPECTION_REQUIRED` | 当前故障不处于待复检状态 |
| `OPERATIONS_REVIEW_REQUEST_NOT_FOUND` | 运维审核请求不存在 |
| `OPERATIONS_REVIEW_REQUEST_ALREADY_REVIEWED` | 运维审核请求已审核 |
| `OPERATIONS_REVIEW_REQUEST_INVALID` | 运维审核请求内容无效 |

## 20. 待确认问题

- 是否需要刷新令牌接口。
- 附件上传是否采用直传对象存储。
- 二维码是否需要过期时间和轮换机制。
- 离线批量同步是否需要全局幂等键。
- 维修人员位置来源和更新频率。
- 是否为 Web 管理后台复用同一套 API。

