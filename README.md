# RDVP

RDVP 是一个基于 HarmonyOS 的远程设备核验与运维报告系统。项目面向分布式设备管理场景，提供设备编号查询、二维码防伪查询、设备状态核验、设备信息变更审核、故障报告、维修接单、维修报告、重大故障复检、离线草稿和操作审计等能力。

本仓库当前处于工程初始化和需求设计阶段，后续将逐步补充 HarmonyOS 移动端、后端服务、数据库脚本、接口文档和部署说明。

## 项目组成

```text
RDVP/
  AppScope/                  HarmonyOS 应用级配置
  entry/                     HarmonyOS 主模块
  docs/                      项目文档
  hvigor/                    Hvigor 构建配置
  build-profile.json5        工程构建配置
  code-linter.json5          代码检查配置
  hvigorfile.ts              根构建脚本
  oh-package.json5           OpenHarmony 包配置
  oh-package-lock.json5      依赖锁定文件
```

## 文档索引

| 文档 | 说明 |
| --- | --- |
| [docs/01-requirements.md](docs/01-requirements.md) | 需求说明、业务流程、角色权限、状态设计和安全要求 |
| [docs/06-development-rules.md](docs/06-development-rules.md) | 开发规范、命名规则、Git 规则和安全约束 |
| [CHANGELOG.md](CHANGELOG.md) | 项目变更记录 |

## 当前范围

第一版建议优先实现以下能力：

- 用户登录和基础权限控制。
- 设备编号查询。
- 二维码扫描查询和后端防伪校验。
- 设备详情展示。
- 设备信息变更申请和管理员审核。
- 故障报告提交。
- 附近维修人员故障推荐。
- 维修人员自主接单。
- 维修报告提交。
- 重大故障复检流程。
- 离线草稿和同步状态提示。
- 操作日志记录。

## 开发环境

- DevEco Studio
- HarmonyOS SDK 6.1.1(24)
- ArkTS
- Stage 模型
- Phone 设备类型

## 仓库要求

- 不提交本地 IDE 配置、构建产物、依赖目录和本机路径配置。
- 不提交真实密钥、证书、Token、生产数据库地址、真实设备编号样本和内部账号。
- 文档、接口、数据库和代码变更必须同步维护。
- 重要业务功能必须经过构建、运行或测试验证后再提交。

