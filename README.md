# RDVP

RDVP 是一个基于 HarmonyOS 的远程档案查询与运维协同系统。项目面向分布式设备管理场景，提供主页数据看板、档案查询、二维码防伪查询、设备状态核验、设备故障报修、档案添加/删除/修改审核、运维审核、维修任务接取、维修任务报告、复检任务报告和日志查询等能力。

本仓库当前包含 HarmonyOS 移动端工程、Spring Boot 后端服务和项目设计文档。移动端已具备中心化主页、登录、主页数据看板、档案查询、二维码查询、核验与报修、档案申请与审核、运维审核、维修任务接取、维修任务报告、复检任务报告和日志查询等基础页面与本地运行闭环；Spring Boot 后端已提供认证、主页数据看板、档案查询、二维码防伪校验、档案申请、管理员审核、运维审核、故障报修、维修任务接取、维修任务报告和复检任务报告等 API。

## 项目组成

```text
RDVP/
  AppScope/                  HarmonyOS 应用级配置
  entry/                     HarmonyOS 主模块
  rdvp-backend/              Spring Boot 后端服务
  docs/                      项目文档
  hvigor/                    Hvigor 构建配置
  build-profile.json5        工程构建配置
  code-linter.json5          代码检查配置
  hvigorfile.ts              根构建脚本
  package.json               后端便捷脚本配置
  package-lock.json          npm 锁定文件
  oh-package.json5           OpenHarmony 包配置
  oh-package-lock.json5      依赖锁定文件
```

## 文档索引

| 文档 | 说明 |
| --- | --- |
| [docs/01-requirements.md](docs/01-requirements.md) | 需求说明、业务流程、角色权限、状态设计和安全要求 |
| [docs/02-architecture.md](docs/02-architecture.md) | 系统架构、工程边界、分层设计、核心业务流向和安全边界 |
| [docs/03-api-design.md](docs/03-api-design.md) | API 设计、通用响应、错误码、接口分组和核心业务接口 |
| [docs/04-database-design.md](docs/04-database-design.md) | 数据库设计、核心实体、字段、约束、索引和数据一致性规则 |
| [docs/05-security-design.md](docs/05-security-design.md) | 安全设计、认证授权、二维码防伪、附件安全、离线数据和审计要求 |
| [docs/06-development-rules.md](docs/06-development-rules.md) | 开发规范、命名规则、Git 规则和安全约束 |
| [CHANGELOG.md](CHANGELOG.md) | 项目变更记录 |

## 当前范围

第一版建议优先实现以下能力：

- 用户登录和基础权限控制。
- 档案查询，包含设备编号查询和二维码查询。
- 二维码后端防伪校验。
- 档案详情展示。
- 档案添加、删除和修改申请以及管理员审核。
- 设备故障报修提交。
- 维修和复检任务推荐。
- 维修人员自主接取。
- 维修任务报告提交。
- 重大故障复检任务流程。
- 档案审核和运维审核。
- 日志查询和操作日志记录。

## 开发环境

- DevEco Studio
- HarmonyOS SDK 6.1.1(24)
- ArkTS
- Stage 模型
- Phone 设备类型
- Java 25 LTS
- Maven Wrapper
- Docker Desktop
- PostgreSQL + PostGIS

## 本地联调

后端服务独立运行，不会随 HarmonyOS App 安装到模拟器或真机。联调时先启动 `rdvp-backend`；App 登录时会在内部探测后端健康检查地址，连接成功后缓存可用地址。登录页只需要输入账号和密码。

```powershell
cd rdvp-backend
docker compose up -d postgres
.\mvnw.cmd spring-boot:run "-Dspring-boot.run.profiles=local"
```

后端候选地址位于移动端 `ApiClient` 配置中，当前包含本机和模拟器宿主机常用地址。真机访问电脑本机服务时，通常应把电脑在局域网中的地址加入候选列表，例如：

```text
http://192.168.x.x:8080
```

## 仓库要求

- 不提交本地 IDE 配置、构建产物、依赖目录和本机路径配置。
- 不提交真实密钥、证书、Token、生产数据库地址、真实设备编号样本和内部账号。
- 文档、接口、数据库和代码变更必须同步维护。
- 重要业务功能必须经过构建、运行或测试验证后再提交。
