# RDVP Backend

RDVP Backend 是 RDVP 移动端应用的后端服务，负责认证、设备档案、二维码校验、运维流程、管理审核、审计日志和附件等服务端能力。

## 技术栈

- Java 25 LTS
- Spring Boot 4
- Spring Web MVC
- Spring Security
- Spring Boot Actuator
- Spring Validation
- MyBatis
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

## 本地引导账号

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

本地可复制 `.env.example` 为 `.env` 后按需修改，`.env` 不应提交到版本库。

如果 Docker Hub 无法访问，可在本地 `.env` 中临时覆盖 `RDVP_POSTGIS_IMAGE`。不要将个人网络代理或非官方镜像地址提交到版本库。
