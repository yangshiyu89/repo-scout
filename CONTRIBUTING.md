# Contributing to Repo Scout

感谢您对 Repo Scout 项目的关注！我们欢迎各种形式的贡献，包括但不限于：

- 🐛 报告 Bug
- ✨ 提出新功能建议
- 📝 改进文档
- 🧪 添加测试用例
- 💡 代码优化
- 🌍 国际化支持

## 🚀 开始贡献

### 开发环境设置

1. Fork 本仓库到您的 GitHub 账户
2. Clone 您的 fork 仓库：
```bash
git clone https://github.com/YOUR_USERNAME/repo-scout.git
cd repo-scout
```

3. 创建开发分支：
```bash
git checkout -b feature/your-feature-name
```

### 代码规范

请遵循以下代码规范：

- 使用 4 个空格进行缩进
- 行长度限制为 88 字符
- 使用描述性的变量和函数名
- 添加必要的注释和文档字符串

### 提交规范

提交信息格式：
```
type(scope): description

[optional body]

[optional footer]
```

类型说明：
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

示例：
```
feat(download): add support for custom download mirrors

- Add configuration option for custom mirror URLs
- Update hfd.sh script to use custom mirrors
- Add tests for mirror functionality

Closes #123
```

## 📋 贡献流程

### 1. 报告 Bug

如果您发现了 Bug，请：

1. 检查是否已有相关 issue
2. 创建新 issue，包含：
   - Bug 描述
   - 复现步骤
   - 期望行为
   - 实际行为
   - 环境信息（操作系统、Python 版本等）

### 2. 提出新功能

在提出新功能前，请：

1. 检查是否已有相关讨论
2. 创建 feature request，描述：
   - 功能需求
   - 使用场景
   - 预期效果
   - 可能的实现方案

### 3. 提交代码

1. 确保代码通过所有测试
2. 更新相关文档
3. 提交 Pull Request，包含：
   - 清晰的标题和描述
   - 相关的 issue 编号
   - 测试结果截图

## 🧪 测试

运行测试：

```bash
# 运行所有测试
pytest tests/

# 运行特定测试
pytest tests/test_download.py

# 生成覆盖率报告
pytest --cov=repo_scout tests/
```

## 📖 文档

文档改进也是重要的贡献形式：

- 修复错误或不清晰的地方
- 添加使用示例
- 翻译文档到其他语言
- 添加 API 文档

## 🤝 代码审查

所有 Pull Request 都需要经过代码审查：

1. 自动化检查（CI/CD）
2. 维护者人工审查
3. 根据反馈进行修改

## 🏷️ 发布流程

发布新版本：

1. 更新版本号
2. 更新 CHANGELOG.md
3. 创建 Git tag
4. 自动构建和发布

## 💬 沟通渠道

- GitHub Issues: 报告 Bug 和功能请求
- GitHub Discussions: 一般讨论和问答
- Email: repo-scout@example.com

## 📜 行为准则

请遵守我们的行为准则：

- 尊重他人，友善交流
- 接受并建设性地反馈意见
- 专注于对社区最有利的事情
- 对其他社区成员表示同理心

## 🎉 致谢

感谢所有为 Repo Scout 做出贡献的开发者！

您的贡献将被记录在项目贡献者列表中，并在每个版本的发布说明中提及。

---

再次感谢您的贡献！🎉