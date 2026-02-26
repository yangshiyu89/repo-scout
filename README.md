# Repo Scout - AI 模型快速调研工具

<div align="center">
  <img src="https://img.shields.io/badge/Python-3.8%2B-blue" alt="Python version">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/PRs-Welcome-brightgreen" alt="PRs Welcome">
</div>

## 🌟 简介

Repo Scout 是一个强大的 AI 模型快速调研和部署工具，专门设计用于帮助开发者快速上手开源 AI 模型仓库。它自动化了从环境搭建到推理执行的全过程，让你能够快速体验各种 AI 模型的能力。

## ✨ 核心特性

- 🔧 **智能环境搭建** - 自动分析项目依赖，使用 uv 替代 conda 构建高效环境
- 📦 **多源模型下载** - 支持 ModelScope 和 HuggingFace 镜像，国内访问友好
- 🚀 **一键推理执行** - 自动发现并运行推理脚本，快速获得结果
- 📋 **完整命令记录** - 记录所有执行命令，便于分享和复现
- 🌍 **跨平台支持** - 兼容 Linux、macOS 和 Windows

## 🎯 适用场景

当你想要：
- "快速上手这个 AI 模型"
- "调研某个开源模型如何使用"
- "部署模型并运行 demo"
- "测试不同模型的性能效果"

## 🚀 快速开始

### 安装前置依赖

```bash
# 安装 uv (推荐)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 安装 aria2c (用于加速下载)
# Ubuntu/Debian
apt-get install -y aria2
# macOS
brew install aria2
```

### 使用方法

1. **调研一个 AI 模型仓库**

```bash
# 示例：调研 Stable Diffusion WebUI
repo-scout https://github.com/AUTOMATIC1111/stable-diffusion-webui

# 示例：调研 Whisper 模型
repo-scout https://github.com/openai/whisper
```

2. **自动处理流程**

Repo Scout 会自动执行以下步骤：
- 📥 克隆仓库到指定目录
- 🔧 使用 uv 创建虚拟环境并安装依赖
- 📦 检查模型是否已下载，如需要则自动下载
- 🎯 准备 demo 数据
- 🚀 运行推理并保存结果

## 📖 详细工作流程

### 第一步：环境搭建

Repo Scout 会自动分析项目的环境需求，并将 conda 命令转换为 uv 方案：

```bash
# 转换示例
conda create -n myenv python=3.10  →  uv venv .venv
conda install pytorch torchvision     →  uv pip install pytorch torchvision
```

### 第二步：模型下载

支持多种模型下载方式：

1. **ModelScope (国内优先)**
```python
from modelscope import snapshot_download
snapshot_download('model_name')
```

2. **HuggingFace 镜像**
```bash
# 使用内置的 hfd.sh 脚本
~/.local/bin/hfd.sh org/model-name --tool aria2c -x 10
```

### 第三步：推理执行

自动发现常见的推理脚本：
- `inference.py`、`demo.py`、`run.py`
- `scripts/inference/` 目录下的脚本

输出统一保存到 `.demo_output/` 目录。

## 🛠️ 高级配置

### 自定义下载参数

```bash
# 使用 HuggingFace 认证下载私有模型
repo-scout --hf-username your_username --hf-token your_token [repo_url]

# 指定下载线程数
repo-scout --threads 16 [repo_url]

# 自定义输出目录
repo-scout --output-dir /path/to/output [repo_url]
```

### 环境变量

```bash
# 设置 HuggingFace 镜像源
export HF_ENDPOINT="https://hf-mirror.com"

# 设置 ModelScope 缓存目录
export MODELSCOPE_CACHE="/path/to/cache"
```

## 📁 项目结构

```
repo-scout/
├── scripts/
│   └── hfd.sh          # HuggingFace 快速下载脚本
├── evals/
│   └── evals.json      # 评估测试用例
├── SKILL.md            # Skill 详细文档
├── README.md            # 项目说明
└── LICENSE              # 开源协议
```

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 如何贡献

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

### 贡献类型

- 🐛 Bug 修复
- ✨ 新功能开发
- 📝 文档改进
- 🧪 测试用例添加
- 💡 性能优化

## 📋 常见问题

| 问题 | 解决方案 |
|------|----------|
| uv 未安装 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| aria2c 未安装 | `apt-get install -y aria2` 或 `brew install aria2` |
| 模型下载失败 | 检查网络连接或使用 VPN |
| GPU 内存不足 | 使用 `--cpu-only` 参数或选择更小的模型 |
| 依赖冲突 | `uv pip install --resolution lowest-direct` |

## 🙏 致谢

- [uv](https://github.com/astral-sh/uv) - 高效的 Python 包管理器
- [ModelScope](https://modelscope.cn/) - 模型即服务共享平台
- [HuggingFace](https://huggingface.co/) - AI 社区和模型库

## 📄 开源协议

本项目采用 [MIT License](LICENSE) 开源协议。

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/repo-scout&type=Date)](https://star-history.com/#yourusername/repo-scout&Date)

---

<div align="center">
  <p>如果觉得有用，请给我们一个 ⭐️</p>
  <p>Made with ❤️ by the Repo Scout Team</p>
</div>