# GitHub 发布指南

## 📋 发布准备清单

在发布到 GitHub 之前，请确认以下事项：

### 1. 账户准备
- [ ] 拥有 GitHub 账户
- [ ] 已安装 Git 并配置好用户信息
- [ ] 已生成 SSH 密钥并添加到 GitHub（推荐）

### 2. 仓库准备
- [ ] 代码已整理到发布目录
- [ ] README.md 已完善
- [ ] LICENSE 文件已添加
- [ ] CONTRIBUTING.md 已创建
- [ ] CHANGELOG.md 已编写
- [ ] .gitignore 文件已准备

### 3. 内容检查
- [ ] 所有脚本权限正确（尤其是 hfd.sh）
- [ ] 文档中的链接有效
- [ ] 代码注释清晰
- [ ] 没有敏感信息泄露

## 🚀 发布步骤

### 步骤 1: 创建 GitHub 仓库

1. 登录 GitHub
2. 点击右上角的 "+" 按钮，选择 "New repository"
3. 填写仓库信息：
   - Repository name: `repo-scout`
   - Description: `AI 模型快速调研工具 - 自动化环境搭建、模型下载和推理执行`
   - 选择 Public（开源项目）或 Private
   - 不要勾选 "Initialize this repository with a README"（我们已经有内容了）
4. 点击 "Create repository"

### 步骤 2: 推送代码到 GitHub

```bash
# 进入项目目录
cd /tmp/repo-scout-github

# 初始化 Git 仓库
git init

# 添加所有文件
git add .

# 第一次提交
git commit -m "Initial release: Repo Scout AI model research tool

Features:
- Smart environment setup with uv
- Multi-source model download support
- Automatic inference execution
- Complete documentation and examples"

# 添加远程仓库（替换为你的用户名）
git remote add origin https://github.com/YOUR_USERNAME/repo-scout.git

# 推送到 GitHub
git push -u origin main
```

### 步骤 3: 仓库设置

1. 进入 GitHub 仓库页面
2. 点击 "Settings" 标签
3. 配置以下选项：

#### 3.1 仓库描述和标签
- 添加 Topics: `ai`, `machine-learning`, `model-deployment`, `automation`, `python`
- 更新仓库描述

#### 3.2 Features
- 启用 "Issues"（用于 Bug 报告和功能请求）
- 启用 "Projects"（项目管理）
- 启用 "Wiki"（详细文档）
- 启用 "Discussions"（社区讨论）

#### 3.3 Merge button
- 设置默认分支为 `main`
- 配置合并策略（建议 "Allow squash merging"）

### 步骤 4: 创建 Release

1. 点击 "Releases" 页面
2. 点击 "Create a new release"
3. 填写信息：
   - Tag version: `v1.0.0`
   - Release title: `Repo Scout v1.0.0 - Initial Release`
   - Description: 复制 CHANGELOG.md 中的 v1.0.0 内容
4. 点击 "Publish release"

### 步骤 5: 设置 GitHub Pages（可选）

1. 在 Settings 中找到 "Pages" 部分
2. Source: 选择 "Deploy from a branch"
3. Branch: 选择 `main` 和 `/ (root)`
4. 选择主题或使用自定义 HTML

## 🎉 发布后操作

### 1. 推广宣传
- 在相关社区分享（Reddit, Hacker News, V2EX）
- 在社交媒体宣传
- 写技术博客介绍

### 2. 建立社区
- 及时回复 Issue
- 参与 Discussion
- 感谢贡献者

### 3. 持续维护
- 定期更新依赖
- 修复 Bug
- 添加新功能
- 更新文档

## 📊 项目徽章

在 README.md 顶部添加这些徽章：

```markdown
<div align="center">
  <img src="https://img.shields.io/badge/Python-3.8%2B-blue" alt="Python version">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/PRs-Welcome-brightgreen" alt="PRs Welcome">
  <img src="https://img.shields.io/github/stars/YOUR_USERNAME/repo-scout?style=social" alt="GitHub stars">
  <img src="https://img.shields.io/github/forks/YOUR_USERNAME/repo-scout?style=social" alt="GitHub forks">
</div>
```

## 🔄 持续集成（可选）

添加 GitHub Actions 工作流：

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.8, 3.9, '3.10', 3.11]
    
    steps:
    - uses: actions/checkout@v3
    - name: Set up Python
      uses: actions/setup-python@v3
      with:
        python-version: ${{ matrix.python-version }}
    
    - name: Install dependencies
      run: |
        pip install -r requirements.txt
    
    - name: Run tests
      run: |
        pytest tests/
```

## 📝 发布脚本（自动化）

创建一个发布脚本 `scripts/release.sh`：

```bash
#!/bin/bash

set -e

VERSION=$1
if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh <version>"
    exit 1
fi

echo "Creating release $VERSION..."

# 更新版本号
echo "$VERSION" > VERSION

# 提交更改
git add .
git commit -m "Release $VERSION"

# 创建 tag
git tag -a "$VERSION" -m "Release $VERSION"

# 推送到远程
git push origin main
git push origin "$VERSION"

echo "Release $VERSION created successfully!"
```

---

🎊 恭喜！你的 Repo Scout 项目现在已经成功发布到 GitHub！

记得保持活跃，持续改进项目，与社区保持互动！