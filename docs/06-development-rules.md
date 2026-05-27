# RDVP 开发规范

## 1. 基本原则

RDVP 按正式工程标准开发，不按示例项目、临时实验或课程 Demo 的方式组织代码。

所有目录、文件、接口、数据表、枚举、状态和提交记录都应具备清晰语义。不得保留无业务意义的 `demo`、`example`、`test1`、`temp`、`foo`、`bar` 等命名。

## 2. 仓库结构规则

当前仓库先承载 HarmonyOS 移动端工程和项目文档。后续新增后端服务、数据库脚本或部署配置时，应按清晰边界放置：

```text
RDVP/
  AppScope/
  entry/
  docs/
  backend-service/
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
- 设备信息变更申请：`device change request`
- 故障报告：`fault report`
- 维修任务：`repair task`
- 维修报告：`repair report`
- 复检记录：`reinspection record`
- 操作日志：`operation log`

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

