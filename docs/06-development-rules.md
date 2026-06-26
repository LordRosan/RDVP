# RDVP 开发规范

## 1. 基本原则

本规范用于统一 RDVP 仓库的目录组织、命名方式、Git 使用、安全边界和质量要求。

所有目录、文件、接口、数据表、枚举、状态和提交记录都应具备清晰语义。命名应避免使用 `demo`、`example`、`test1`、`temp`、`foo`、`bar` 等无业务含义的占位词。

## 2. 仓库结构规则

当前仓库承载 HarmonyOS 移动端工程、后端服务和项目文档。后续新增数据库脚本或部署配置时，应按清晰边界放置：

```text
RDVP/
  AppScope/
  entry/
  rdvp-backend/
  docs/
  database/
  deployment/
```

新增目录前必须确认其职责，不能因为单个文件临时创建含义模糊的目录。

## 3. 命名规则

### 3.1 项目和模块

- 项目名使用 `RDVP`。
- HarmonyOS 主模块保留 `entry`。
- 包名使用正式标识，不得使用 `com.example.*`。

### 3.2 文档

文档放在 `docs/` 目录下，并使用两位数字前缀控制阅读顺序：

```text
01-requirements.md
02-architecture.md
03-api-design.md
04-database-design.md
05-security-design.md
06-development-rules.md
```

### 3.3 业务命名

业务命名必须围绕真实领域概念：

- 设备：`device`
- 设备核验：`device verification`
- 设备档案申请：`device archive request`
- 设备故障报修：`device fault report`
- 维修任务：`repair task`
- 维修报告：`repair report`
- 复检任务报告：`reinspection report`
- 操作日志：`operation log`

### 3.4 领域目录和实体命名

前后端目录应围绕一级业务中心和稳定领域划分，优先使用完整英文词，不使用 `Ops`、`Mgmt`、`RecordCenter` 等缩写或旧界面名。

核心领域目录规则：

- `archive` 表示档案领域，用于设备档案、二维码、档案申请和档案审核相关模型与服务。
- `operations` 表示运维领域，是领域集合名，不按普通复数理解；设备核验、故障报修、维修任务和复检任务均归入该领域。
- `management` 表示管理领域，用于档案审核、记录查询和后续管理能力。
- `identity` 表示身份领域，用于认证、会话、角色和权限。
- `app` 表示应用级能力，用于主页、主题、应用设置等跨业务中心能力。
- `common` 表示通用基础能力，用于 API 响应、通用工具和跨领域基础模型。

实体、页面、函数和变量命名应使用单数业务对象表达一个具体概念，例如 `RepairTask`、`RepairReport`、`ReinspectionReport`、`DeviceArchiveRequest`。涉及运维领域时使用 `operations`，例如 `operations` 目录、`OperationsCenter` 页面、`OperationsRecordQuery`。

记录查询作为管理中心下的功能，统一使用 `RecordQuery` 命名，不再使用 `RecordCenter`。运维记录统一使用 `OperationsRecordQuery`，权限码统一使用 `MANAGEMENT_CENTER_OPERATIONS_RECORD_QUERY`。

## 4. Git 规则

### 4.1 分支

建议使用以下分支：

- `main`：稳定分支，保存可构建、可追溯的正式代码。
- `develop`：开发集成分支，可在需要多人协作时启用。
- `feature/<name>`：功能分支。
- `fix/<name>`：缺陷修复分支。
- `docs/<name>`：文档变更分支。

个人开发初期可以直接在 `main` 上提交，但每次提交必须保持清晰、可解释。

### 4.2 提交信息

提交信息建议使用以下格式：

```text
type(scope): summary
```

常用类型：

- `docs`：文档变更。
- `feat`：新增功能。
- `fix`：修复缺陷。
- `refactor`：重构。
- `test`：测试相关。
- `build`：构建配置。
- `chore`：工程维护。

示例：

```text
docs(requirements): add initial business process draft
```

### 4.3 提交前检查

提交前至少确认：

- `git status` 中没有意外文件。
- 没有提交本地配置、构建产物和依赖目录。
- 没有真实密钥、Token、证书、内部地址和真实账号。
- 文档和代码变更保持一致。

## 5. 安全规则

以下内容严禁提交到 GitHub：

- 真实账号和密码。
- 访问 Token。
- API Key。
- 私钥和证书。
- 生产数据库连接地址。
- 内部服务器地址。
- 真实设备编号样本。
- 真实用户个人信息。
- 未脱敏的故障、维修和审计数据。

需要提供配置示例时，应使用模板文件，例如：

```text
.env.example
config.example.json
```

模板文件只能包含占位值，不能包含真实环境信息。

## 6. 文档维护规则

新增或修改业务功能时，应同步检查以下文档：

- 需求是否需要更新。
- 架构设计是否需要更新。
- API 文档是否需要更新。
- 数据库设计是否需要更新。
- 安全设计是否需要更新。
- 变更记录是否需要更新。

不能只修改代码而让文档长期失真。

## 7. 质量要求

重要变更完成后，应根据变更类型执行相应验证：

- HarmonyOS 移动端变更：至少确认工程可构建，关键页面可运行。
- 后端服务变更：至少执行单元测试或接口验证。
- 数据库变更：至少验证迁移脚本和回滚策略。
- 安全相关变更：必须检查鉴权、权限、日志和敏感数据处理。

无法执行验证时，应在提交说明或任务记录中明确说明原因。
