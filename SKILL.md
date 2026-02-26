---
name: repo-scout
description: 快速调研/部署开源 AI 模型仓库并运行推理 demo。当你想要快速上手一个 AI 模型 repo、调研某个开源模型如何使用、部署和运行模型 demo 时使用此 skill。此 skill 会处理环境搭建（使用 uv 而非 conda）、模型下载（支持 modelscope 和 huggingface 镜像）、demo 数据准备和推理执行。Use this skill when the user wants to quickly try out an AI model repository, scout/research an open-source model, or run an inference demo. This skill handles environment setup (using uv instead of conda), model downloading (supports modelscope and huggingface mirror), demo data preparation, and inference execution.
---

# Repo Scout - AI 模型快速调研工具

帮助你快速调研和部署开源 AI 模型仓库，目标是成功运行一个推理 demo。

## 使用场景

当用户说：
- "帮我调研一下这个模型 repo：xxx"
- "我想快速上手 xxx 模型"
- "帮我部署 xxx 模型并跑个 demo"
- "这个开源项目怎么跑？"

## 工作流程

### 第一步：获取 Repo 信息

1. 询问用户 GitHub 仓库地址（如果还没有提供）
2. 询问用户要将 repo clone 到哪个目录
3. Clone 仓库到指定目录

### 第二步：环境搭建

**重要：严禁使用 conda，必须使用 uv**

1. **分析项目的环境需求**：
   - 读取 README、requirements.txt、setup.py、pyproject.toml 等文件
   - 如果文档中提到 conda，将其转换为 uv 方案

2. **使用 uv 创建虚拟环境**：
   ```bash
   cd <repo_directory>
   uv venv .venv
   source .venv/bin/activate  # Linux/Mac
   # 或 .venv\Scripts\activate  # Windows
   ```

3. **安装依赖**：
   ```bash
   # 如果有 requirements.txt
   uv pip install -r requirements.txt
   
   # 如果有 setup.py 或 pyproject.toml
   uv pip install -e .
   
   # 如果需要额外依赖
   uv pip install <package>
   ```

4. **处理常见问题**：
   - 如果需要特定 Python 版本，提示用户确保系统已安装该版本
   - 如果需要 CUDA，检测系统 GPU 配置

### 第三步：模型/数据下载

1. **询问用户模型是否已下载**：
   - 如果已下载，记录模型路径
   - 如果未下载，继续下一步

2. **使用 ModelScope SDK 查询模型**（仅适用于国内可访问的模型）：
   ```python
   # 使用 modelscope SDK 查询
   pip install modelscope
   from modelscope import snapshot_download
   ```
   
   - 从 repo 名称推断可能的 ModelScope 模型名
   - 查询是否存在同名或相似模型
   - 如果找到，告知用户并提供下载命令

3. **如果 ModelScope 没有，使用 hfd.sh 从 HuggingFace 镜像下载**：

   **重要**：hfd.sh 仅适用于 HuggingFace 的模型和数据集

   **步骤 3.1：检查并安装 aria2c**
   ```bash
   # 检查 aria2c 是否已安装
   which aria2c || apt-get install -y aria2
   ```

   **步骤 3.2：部署 hfd.sh 脚本**
   此 skill 已打包 hfd.sh 脚本，首次使用时复制到用户目录：
   ```bash
   mkdir -p ~/.local/bin
   cp <skill_path>/scripts/hfd.sh ~/.local/bin/hfd.sh
   chmod +x ~/.local/bin/hfd.sh
   ```

   **步骤 3.3：下载模型或数据**
   ```bash
   # 下载公开模型
   ~/.local/bin/hfd.sh <org/model-name> --tool aria2c -x 10
   
   # 示例：下载 bloom-560m 模型
   ~/.local/bin/hfd.sh bigscience/bloom-560m --tool aria2c -x 10
   
   # 下载需要认证的模型（询问用户的 hf_username 和 hf_token）
   ~/.local/bin/hfd.sh <org/model-name> --hf_username <username> --hf_token <token> --tool aria2c -x 10
   
   # 下载数据集（使用 --dataset 参数）
   ~/.local/bin/hfd.sh <org/dataset-name> --hf_username <username> --hf_token <token> --dataset
   ```

   **步骤 3.4：如果模型需要认证**
   - 询问用户是否有 HuggingFace 账号
   - 如果需要，询问用户的 `--hf_username` 和 `--hf_token`
   - Token 可从 https://huggingface.co/settings/tokens 获取

   **hfd.sh 依赖**：aria2c、wget、curl、git、git-lfs

4. **记录模型/数据路径**供后续推理使用

### 第四步：Demo 数据准备

1. **从 repo 自带示例获取**：
   - 检查 repo 中的 `assets/`、`examples/`、`demo/`、`data/` 等目录
   - 检查 README 中提到的示例数据
   - 如果推理脚本中有默认输入路径，使用那些

2. **如果没有现成数据**：
   - 根据模型类型（图像、文本、音频、视频等）创建简单的测试输入
   - 或提示用户提供测试数据

### 第五步：推理执行

1. **检查是否有现成的推理脚本**：
   - 常见推理脚本位置：`inference.py`、`demo.py`、`run.py`、`scripts/inference/`
   - 如果没有推理脚本，告知用户此 repo 不支持

2. **自动检测 GPU 配置**：
   ```bash
   # 检测可用 GPU
   nvidia-smi --query-gpu=index,name,memory.total --format=csv
   
   # 检测 CUDA 版本
   nvcc --version
   ```

3. **设置输出目录**：
   - 默认输出到 `<repo_directory>/.demo_output/`
   - 创建输出目录

4. **运行推理**：
   - 根据推理脚本的要求设置参数
   - 如果需要指定模型路径，使用第三步记录的路径
   - 如果需要指定输入数据，使用第四步准备的路径
   - 输出重定向到 `.demo_output/`

5. **记录执行的命令**供用户参考

### 第六步：结果验证

1. 检查 `.demo_output/` 目录是否有输出文件
2. 告知用户输出文件的位置
3. 用户自行检查输出结果的质量

## 命令记录模板

在整个过程中，记录所有执行的关键命令：

```markdown
## 调研命令记录

### 环境搭建
```bash
cd /path/to/repo
uv venv .venv
source .venv/bin/activate
uv pip install -r requirements.txt
```

### 模型/数据下载
```bash
# ModelScope 下载（如果使用）
pip install modelscope
python -c "from modelscope import snapshot_download; snapshot_download('model-name')"

# 或 HuggingFace 镜像下载（如果使用）
# 下载模型
~/.local/bin/hfd.sh bigscience/bloom-560m --tool aria2c -x 10

# 下载数据集（如需认证）
~/.local/bin/hfd.sh org/dataset-name --hf_username <user> --hf_token <token> --dataset
```

### 推理执行
```bash
python inference.py --model /path/to/model --input /path/to/input --output .demo_output/
```
```

## 注意事项

1. **禁止使用 conda**：
   - 如果项目 README 中提到 conda，必须将其转换为 uv 方案
   - conda 创建环境 → uv venv
   - conda install → uv pip install
   - pip install → uv pip install（保持不变）

2. **模型下载优先级**：
   - 首先询问用户是否已有模型
   - 其次尝试 ModelScope（国内友好）
   - 最后使用 hfd.sh 从 HuggingFace 镜像下载（仅支持 HF 模型和数据集）

3. **hfd.sh 使用注意**：
   - 仅适用于 HuggingFace 的模型和数据集
   - 需要先安装 aria2c：`apt-get install -y aria2`
   - 部分模型需要提供 `--hf_username` 和 `--hf_token`
   - 下载数据集时需添加 `--dataset` 参数

4. **仅支持有推理脚本的 repo**：
   - 如果找不到推理脚本，明确告知用户
   - 不要尝试自动生成推理代码

5. **GPU 检测**：
   - 自动检测但不强制要求
   - 如果需要 GPU 但没有，告知用户

6. **输出目录**：
   - 始终使用 `<repo>/.demo_output/` 作为输出目录
   - 避免污染 repo 主目录

## 常见问题处理

| 问题 | 解决方案 |
|------|----------|
| uv 未安装 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| aria2c 未安装 | `apt-get install -y aria2` 或 `brew install aria2` |
| hfd.sh 下载失败 | 检查网络，或尝试直接使用 huggingface-cli |
| HF 模型需要认证 | 询问用户的 --hf_username 和 --hf_token |
| 依赖冲突 | 使用 `uv pip install --resolution lowest-direct` |
| CUDA 版本不匹配 | 提示用户安装正确版本的 PyTorch |
| 内存不足 | 建议 CPU 模式或更小的模型 |

## 示例交互

**用户**: 帮我调研一下 https://github.com/xxx/awesome-model

**Agent**:
1. 询问 clone 目录 → `/home/user/projects/awesome-model`
2. Clone repo
3. 分析环境需求，使用 uv 搭建环境
4. 询问模型是否已下载 → 没有
5. 检查 ModelScope → 找到同名模型 → 下载
6. 检查 demo 数据 → 使用 `examples/` 目录中的图片
7. 找到推理脚本 `inference.py`
8. 运行推理，输出到 `.demo_output/`
9. 记录所有命令
10. 告知用户输出位置，请用户检查结果
