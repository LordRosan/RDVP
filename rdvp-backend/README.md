# RDVP Backend

RDVP Backend 是 RDVP 移动端应用的后端服务，负责认证、设备档案、二维码校验、运维流程、管理审核和系统健康检查等服务端能力。

## 技术栈

- Java 25 LTS
- Spring Boot 4
- Spring Web MVC
- Spring Security
- Spring Boot Actuator
- Spring Validation
- Spring JDBC
- PostgreSQL + PostGIS
- Flyway
- Maven

## 本地运行

确认 Docker Desktop 已启动后，启动本地数据库：

```powershell
docker compose up -d postgres
```

运行测试：

```powershell
.\mvnw.cmd test
```

启动后端服务：

```powershell
.\mvnw.cmd spring-boot:run
```

健康检查：

```text
GET http://localhost:8080/healthz
GET http://localhost:8080/readyz
GET http://localhost:8080/actuator/health
```

登录接口：

```text
POST http://localhost:8080/api/v1/auth/login
```

请求示例：

```json
{
  "username": "fieldoperator",
  "password": "password",
  "clientDeviceId": "local-device"
}
```

后续业务请求使用返回的访问凭证：

```text
Authorization: Bearer <accessToken>
```

## 已实现业务接口

设备档案查询：

```text
GET http://localhost:8080/api/v1/devices/by-code/RDVP-DEVICE-0001
GET http://localhost:8080/api/v1/devices/device-local-0001
```

二维码核验并查询设备：

```text
POST http://localhost:8080/api/v1/device-qrcodes/verify
```

请求示例：

```json
{
  "qrContent": "RDVP:1:RDVP-DEVICE-0001:nonce-rdvp-device-0001:f36d5f8b2a520071a5955968704a6dd4017a01e6457f573527867e47813c2807"
}
```

本地种子数据包含以下临时二维码内容，可用于移动端二维码识别和接口联调：

| 设备编号 | 二维码内容 |
| --- | --- |
| `RDVP-DEVICE-0001` | `RDVP:1:RDVP-DEVICE-0001:nonce-rdvp-device-0001:f36d5f8b2a520071a5955968704a6dd4017a01e6457f573527867e47813c2807` |
| `RDVP-DEVICE-0002` | `RDVP:1:RDVP-DEVICE-0002:nonce-rdvp-device-0002:c5fb24d08793ff6e3b4a7422874c765e2455d4f6dee7aca680b246b4222f8a37` |
| `RDVP-DEVICE-0003` | `RDVP:1:RDVP-DEVICE-0003:nonce-rdvp-device-0003:6efde5c2594d434cf9294cc04dccd765eb9debd1fc7ec081f13fbe54e7bc6c97` |

二维码签名密钥通过 `RDVP_QR_SIGNING_SECRET` 配置。本地默认值仅用于开发联调，部署环境必须使用独立密钥。

设备档案变更申请：

```text
POST http://localhost:8080/api/v1/device-change-requests
```

请求示例：

```json
{
  "deviceId": "device-local-0001",
  "reason": "Device name correction.",
  "changes": {
    "name": {
      "oldValue": "Cooling Pump A-01",
      "newValue": "Cooling Pump A-02"
    }
  }
}
```

管理员查询和审核变更申请：

```text
GET http://localhost:8080/api/v1/device-change-requests?status=PENDING_REVIEW
POST http://localhost:8080/api/v1/device-change-requests/{requestId}/review
```

审核请求示例：

```json
{
  "decision": "APPROVED",
  "reviewedAt": "2026-06-01T08:00:00Z",
  "reviewComment": "Approved."
}
```

故障、维修和复检流程：

```text
POST http://localhost:8080/api/v1/fault-reports
GET http://localhost:8080/api/v1/repair-tasks/available?radiusKm=10
POST http://localhost:8080/api/v1/fault-reports/{faultReportId}/accept
GET http://localhost:8080/api/v1/repair-tasks/my
POST http://localhost:8080/api/v1/repair-tasks/{repairTaskId}/repair-reports
GET http://localhost:8080/api/v1/reinspections/pending
POST http://localhost:8080/api/v1/fault-reports/{faultReportId}/reinspection-records
```

## 本地引导账号

数据库模式下，本地引导账号会在服务启动时写入 `users`、`user_roles`、`user_permissions` 表。再次启动时会同步账号显示名、状态、角色和权限，但不会覆盖已经存在的密码哈希；测试配置使用内存账号仓储。

| 用户名 | 密码 | 角色 |
| --- | --- | --- |
| `admin` | `password` | `SYSTEM_ADMIN` |
| `deviceadmin` | `password` | `DEVICE_ADMIN` |
| `fieldoperator` | `password` | `FIELD_OPERATOR` |
| `maintainer` | `password` | `MAINTAINER` |
| `reinspector` | `password` | `REINSPECTOR` |
| `auditor` | `password` | `SUPERVISOR_AUDITOR` |
| `readonly` | `password` | `READ_ONLY` |

## 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `SERVER_PORT` | `8080` | HTTP 服务端口 |
| `RDVP_SERVICE_NAME` | `rdvp-backend` | 服务名称 |
| `RDVP_SERVICE_VERSION` | `0.1.0` | 服务版本 |
| `RDVP_DATASOURCE_URL` | `jdbc:postgresql://localhost:5432/rdvp` | 数据库连接地址 |
| `RDVP_DATASOURCE_USERNAME` | `rdvp` | 数据库用户名 |
| `RDVP_DATASOURCE_PASSWORD` | `rdvp_dev_password` | 数据库密码 |
| `RDVP_POSTGIS_IMAGE` | `postgis/postgis:17-3.5` | 本地 PostGIS 镜像 |
| `RDVP_POSTGRES_PORT` | `5432` | 本地 PostgreSQL 映射端口 |
| `RDVP_BOOTSTRAP_PASSWORD` | `password` | 本地引导账号默认密码 |
| `RDVP_QR_SIGNING_SECRET` | `rdvp-local-development-secret` | 二维码 HMAC 签名密钥 |

本地可复制 `.env.example` 为 `.env` 后按需修改，`.env` 不应提交到版本库。

如果 Docker Hub 无法访问，可在本地 `.env` 中临时覆盖 `RDVP_POSTGIS_IMAGE`。不要将个人网络代理或非官方镜像地址提交到版本库。
