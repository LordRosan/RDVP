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

本文档定义 RDVP 后端服务对移动端应用提供的 HTTP API。接口覆盖用户认证、设备查询、二维码校验、设备核验、设备信息变更、故障报告、维修任务、维修报告、复检、附件、通知和审计日志等业务。

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
    "permissions": ["ARCHIVE_DEVICE_READ", "OPS_FAULT_REPORT_CREATE"]
  }
}
```

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
  "permissions": ["ARCHIVE_DEVICE_READ", "OPS_FAULT_REPORT_CREATE"]
}
```

### 5.3 退出登录

```text
POST /api/v1/auth/logout
```

响应数据：

```json
{
  "loggedOut": true
}
```

## 6. 设备接口

### 6.1 通过设备编号查询设备

```text
GET /api/v1/devices/by-code/{deviceCode}
```

权限要求：`ARCHIVE_DEVICE_READ`

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
  "changeState": {
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

权限要求：`ARCHIVE_DEVICE_READ`

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
  "changeState": {
    "locked": false,
    "pendingRequestId": null,
    "freezeUntil": null
  },
  "recentFaultReports": [],
  "recentRepairReports": [],
  "recentVerificationRecords": []
}
```

### 6.3 查询设备列表

```text
GET /api/v1/devices
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `keyword` | 设备编号、名称或型号关键词 |
| `status` | 设备状态 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

## 7. 二维码接口

### 7.1 校验二维码并查询设备

```text
POST /api/v1/device-qrcodes/verify
```

权限要求：`ARCHIVE_DEVICE_READ`

二维码内容格式：

```text
RDVP:<version>:<deviceCode>:<nonce>:<signature>
```

`signature` 使用 HMAC-SHA256 计算，签名原文为 `<version>:<deviceCode>:<nonce>`。服务端会同时校验设备编号、随机标识、二维码状态、过期时间和签名摘要。

请求体：

```json
{
  "qrContent": "RDVP:1:RDVP-DEVICE-0001:nonce:signature",
  "scanLocation": {
    "longitude": 114.1694,
    "latitude": 22.3193
  },
  "scannedAt": "2026-05-27T07:30:00Z"
}
```

`scanLocation` 和 `scannedAt` 为预留字段，用于后续审计、风控和现场核验联动；当前最小实现只要求 `qrContent`。

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

## 8. 设备核验接口

### 8.1 提交设备核验记录

```text
POST /api/v1/devices/{deviceId}/verification-records
```

请求体：

```json
{
  "result": "NORMAL",
  "description": "Device is operating normally.",
  "remark": "No abnormal noise.",
  "verifiedAt": "2026-05-27T07:30:00Z",
  "location": {
    "longitude": 114.1694,
    "latitude": 22.3193
  }
}
```

响应数据：

```json
{
  "id": "verification-record-id",
  "deviceId": "device-id",
  "result": "NORMAL",
  "description": "Device is operating normally.",
  "verifiedAt": "2026-05-27T07:30:00Z",
  "createdAt": "2026-05-27T07:30:00Z"
}
```

### 8.2 查询设备核验记录

```text
GET /api/v1/devices/{deviceId}/verification-records
```

支持分页参数。

## 9. 设备信息变更申请接口

### 9.1 创建设备信息变更申请

```text
POST /api/v1/device-change-requests
```

请求体：

```json
{
  "deviceId": "device-id",
  "reason": "Location information is outdated.",
  "changes": {
    "location.address": {
      "oldValue": "Old address",
      "newValue": "New address"
    },
    "status": {
      "oldValue": "NORMAL",
      "newValue": "PENDING_VERIFICATION"
    }
  },
  "attachmentIds": ["attachment-id"]
}
```

后端创建申请前必须校验：

- 设备不存在待审核变更申请。
- 设备不处于变更冻结期。
- 提交的新值与当前设备档案存在有效差异。

响应数据：

```json
{
  "id": "change-request-id",
  "status": "PENDING_REVIEW",
  "createdAt": "2026-05-27T07:30:00Z"
}
```

### 9.2 查询变更申请列表

```text
GET /api/v1/device-change-requests
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `deviceCode` | 设备编号 |
| `status` | 申请状态 |
| `applicantId` | 申请人 ID |
| `page` | 页码 |
| `pageSize` | 每页数量 |

### 9.3 审核设备信息变更申请

```text
POST /api/v1/device-change-requests/{requestId}/review
```

请求体：

```json
{
  "decision": "APPROVED",
  "reviewComment": "Approved."
}
```

响应数据：

```json
{
  "id": "change-request-id",
  "status": "APPROVED",
  "reviewedAt": "2026-05-27T07:30:00Z",
  "freezeUntil": "2026-05-27T19:30:00Z"
}
```

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
  "location": {
    "longitude": 114.1694,
    "latitude": 22.3193
  },
  "attachmentIds": ["attachment-id"]
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

### 10.2 查询故障报告列表

```text
GET /api/v1/fault-reports
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `deviceCode` | 设备编号 |
| `status` | 故障状态 |
| `faultType` | 故障类型 |
| `severity` | 故障等级 |
| `nearLongitude` | 附近查询经度 |
| `nearLatitude` | 附近查询纬度 |
| `radiusKm` | 附近查询半径，单位 km |
| `page` | 页码 |
| `pageSize` | 每页数量 |

### 10.3 获取故障报告详情

```text
GET /api/v1/fault-reports/{faultReportId}
```

### 10.4 驳回故障报告

```text
POST /api/v1/fault-reports/{faultReportId}/reject
```

请求体：

```json
{
  "reason": "Invalid fault report."
}
```

## 11. 维修任务接口

### 11.1 查询附近可接取故障

```text
GET /api/v1/repair-tasks/available
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `longitude` | 当前经度 |
| `latitude` | 当前纬度 |
| `radiusKm` | 查询半径，默认 10 |
| `severity` | 故障等级 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

### 11.2 接取故障任务

```text
POST /api/v1/fault-reports/{faultReportId}/accept
```

请求体：

```json
{
  "acceptedLocation": {
    "longitude": 114.1694,
    "latitude": 22.3193
  }
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

### 11.3 查询我的维修任务

```text
GET /api/v1/repair-tasks/my
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
  "partsUsed": "Power module x1",
  "attachmentIds": ["attachment-id"]
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

支持分页参数。

### 13.2 提交复检记录

```text
POST /api/v1/fault-reports/{faultReportId}/reinspection-records
```

请求体：

```json
{
  "result": "PASSED",
  "description": "Repair result verified.",
  "reinspectedAt": "2026-05-27T07:30:00Z",
  "attachmentIds": ["attachment-id"]
}
```

响应数据：

```json
{
  "id": "reinspection-record-id",
  "faultReportId": "fault-report-id",
  "result": "PASSED",
  "nextFaultStatus": "CLOSED",
  "nextDeviceStatus": "NORMAL",
  "createdAt": "2026-05-27T07:30:00Z"
}
```

## 14. 附件接口

### 14.1 上传附件

```text
POST /api/v1/attachments
```

请求格式：

```text
multipart/form-data
```

字段：

| 字段 | 说明 |
| --- | --- |
| `file` | 文件内容 |
| `businessType` | 业务类型 |
| `businessId` | 业务对象 ID，可为空 |

响应数据：

```json
{
  "id": "attachment-id",
  "fileName": "image.jpg",
  "contentType": "image/jpeg",
  "size": 102400,
  "createdAt": "2026-05-27T07:30:00Z"
}
```

### 14.2 获取附件元数据

```text
GET /api/v1/attachments/{attachmentId}
```

### 14.3 下载附件

```text
GET /api/v1/attachments/{attachmentId}/content
```

附件下载必须通过权限校验。

## 15. 离线同步接口

### 15.1 批量同步离线草稿

```text
POST /api/v1/sync/offline-records
```

请求体：

```json
{
  "clientBatchId": "client-batch-id",
  "records": [
    {
      "clientRecordId": "local-record-id",
      "recordType": "FAULT_REPORT",
      "payload": {},
      "createdOfflineAt": "2026-05-27T07:30:00Z"
    }
  ]
}
```

响应数据：

```json
{
  "clientBatchId": "client-batch-id",
  "results": [
    {
      "clientRecordId": "local-record-id",
      "success": true,
      "serverRecordId": "fault-report-id",
      "error": null
    }
  ]
}
```

同步失败的单条记录应保留明确错误码和错误信息。

## 16. 通知接口

### 16.1 查询我的通知

```text
GET /api/v1/notifications/my
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `unreadOnly` | 是否只查询未读通知 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

### 16.2 标记通知已读

```text
POST /api/v1/notifications/{notificationId}/read
```

## 17. 审计日志接口

### 17.1 查询操作日志

```text
GET /api/v1/audit-logs
```

查询参数：

| 参数 | 说明 |
| --- | --- |
| `actorId` | 操作人 ID |
| `action` | 操作类型 |
| `targetType` | 操作对象类型 |
| `targetId` | 操作对象 ID |
| `from` | 开始时间 |
| `to` | 结束时间 |
| `page` | 页码 |
| `pageSize` | 每页数量 |

响应数据：

```json
{
  "items": [
    {
      "id": "audit-log-id",
      "action": "FAULT_REPORT",
      "targetType": "FAULT_REPORT",
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
CHANGE_PENDING_REVIEW
FAULTED
UNDER_REPAIR
PENDING_REINSPECTION
DISABLED
RETIRED
```

### 18.2 设备信息变更申请状态

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

### 18.9 操作记录状态

```text
SUCCESS
FAILED
```

### 18.10 离线记录类型

```text
VERIFICATION_RECORD
DEVICE_CHANGE_REQUEST
FAULT_REPORT
REPAIR_REPORT
REINSPECTION_RECORD
```

## 19. 业务错误码

| 错误码 | 说明 |
| --- | --- |
| `DEVICE_NOT_FOUND` | 设备不存在 |
| `DEVICE_CODE_INVALID` | 设备编号格式无效 |
| `QR_CODE_INVALID` | 二维码内容无效 |
| `QR_CODE_EXPIRED` | 二维码已过期 |
| `QR_CODE_SIGNATURE_INVALID` | 二维码签名校验失败 |
| `DEVICE_CHANGE_LOCKED` | 设备存在待审核变更申请 |
| `DEVICE_CHANGE_FROZEN` | 设备处于变更冻结期 |
| `CHANGE_REQUEST_NOT_FOUND` | 设备信息变更申请不存在 |
| `CHANGE_REQUEST_ALREADY_REVIEWED` | 设备信息变更申请已审核 |
| `FAULT_REPORT_NOT_FOUND` | 故障报告不存在 |
| `FAULT_ALREADY_ACCEPTED` | 故障已被其他维修人员接取 |
| `REPAIR_TASK_NOT_FOUND` | 维修任务不存在 |
| `REPAIR_TASK_STATUS_INVALID` | 维修任务状态不允许当前操作 |
| `REINSPECTION_REQUIRED` | 当前故障必须复检 |
| `ATTACHMENT_NOT_FOUND` | 附件不存在 |
| `ATTACHMENT_TYPE_NOT_ALLOWED` | 附件类型不允许 |
| `OFFLINE_RECORD_CONFLICT` | 离线记录与服务端当前状态冲突 |

## 20. 待确认问题

- 是否需要刷新令牌接口。
- 附件上传是否采用直传对象存储。
- 二维码是否需要过期时间和轮换机制。
- 离线批量同步是否需要全局幂等键。
- 维修人员位置来源和更新频率。
- 是否为 Web 管理后台复用同一套 API。
