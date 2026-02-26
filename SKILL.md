---
name: repo-scout
description: 快速调研/部署开源 AI 模型仓库并运行推理 demo。支持并行任务执行、后台运行和进度监控。当你想要快速上手一个 AI 模型 repo、调研某个开源模型如何使用、部署和运行模型 demo 时使用此 skill。
---

# Repo Scout - AI 模型快速调研工具（增强版）

帮助你快速调研和部署开源 AI 模型仓库，支持**并行执行**、**后台运行**和**进度监控**。

## 🆕 增强特性

- ⚡ **并行执行** - 环境搭建和模型下载可同时进行
- 🖥️ **tmux 后台运行** - 长时间任务在后台运行，不怕中断
- 📊 **实时进度监控** - 随时查看任务状态和进度
- 🛡️ **安全退出机制** - 主程序退出时安全停止所有后台任务
- 📋 **任务管理** - 追踪和管理所有后台任务

## 使用场景

当用户说：
- "帮我调研一下这个模型 repo：xxx"
- "我想快速上手 xxx 模型"
- "帮我部署 xxx 模型并跑个 demo"
- "这个开源项目怎么跑？"

## 🔧 核心工作原理

### Skill 的本质

这个 skill 是一个**结构化的指导文档**，为 AI Agent 提供操作指南。实际执行由 AI Agent 完成，Agent 可以：
- 根据情况判断是否并行执行
- 使用 tmux 管理长时间任务
- 监控任务进度
- 安全地管理后台进程

### 执行模式

```
传统模式（串行）：
环境搭建 → 模型下载 → 数据准备 → 推理执行

增强模式（并行）：
┌─────────────┐
│  环境搭建   │───┐
└─────────────┘   │
                  ├──→ 数据准备 → 推理执行
┌─────────────┐   │
│  模型下载   │───┘
└─────────────┘
```

## 📋 完整工作流程

### 第一步：初始化和任务规划

1. **询问用户信息**：
   - GitHub 仓库地址
   - clone 目标目录
   - 模型是否已下载

2. **创建任务管理结构**：
   ```bash
   # 创建任务目录
   mkdir -p <repo_directory>/.task_manager
   mkdir -p <repo_directory>/.task_manager/logs
   mkdir -p <repo_directory>/.task_manager/pids
   
   # 初始化任务状态文件
   cat > <repo_directory>/.task_manager/tasks.json << 'EOF'
   {
     "repo_name": "<repo_name>",
     "start_time": "<timestamp>",
     "tasks": {
       "environment": {"status": "pending", "pid": null},
       "model_download": {"status": "pending", "pid": null},
       "data_prep": {"status": "pending", "pid": null},
       "inference": {"status": "pending", "pid": null}
     }
   }
   EOF
   ```

3. **设置 tmux session**：
   ```bash
   # 检查 tmux 是否安装
   if ! command -v tmux &> /dev/null; then
       echo "安装 tmux..."
       apt-get install -y tmux || brew install tmux
   fi
   
   # 创建专用的 tmux session
   SESSION_NAME="repo-scout-$(date +%Y%m%d_%H%M%S)"
   tmux new-session -d -s $SESSION_NAME -c <repo_directory>
   
   # 记录 session 名称
   echo $SESSION_NAME > <repo_directory>/.task_manager/tmux_session
   ```

### 第二步：并行任务执行

#### 2.1 环境搭建（tmux window 0）

**重要：严禁使用 conda，必须使用 uv**

```bash
# 在 tmux window 中启动环境搭建
tmux new-window -t $SESSION_NAME -n "environment"

# 发送命令到 tmux
tmux send-keys -t $SESSION_NAME:environment "cd <repo_directory>" Enter
tmux send-keys -t $SESSION_NAME:environment "exec > >(tee -a .task_manager/logs/environment.log) 2>&1" Enter

# 创建虚拟环境
tmux send-keys -t $SESSION_NAME:environment "uv venv .venv" Enter
tmux send-keys -t $SESSION_NAME:environment "source .venv/bin/activate" Enter

# 安装依赖（根据项目类型）
if [ -f "requirements.txt" ]; then
    tmux send-keys -t $SESSION_NAME:environment "uv pip install -r requirements.txt" Enter
elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
    tmux send-keys -t $SESSION_NAME:environment "uv pip install -e ." Enter
fi

# 记录完成状态
tmux send-keys -t $SESSION_NAME:environment "echo 'ENVIRONMENT_SETUP_COMPLETE' >> .task_manager/status" Enter

# 记录 PID（用于后续管理）
tmux send-keys -t $SESSION_NAME:environment "echo \$! > .task_manager/pids/environment.pid" Enter
```

#### 2.2 模型/数据下载（tmux window 1）

**同时并行启动**

```bash
# 创建新的 tmux window 用于模型下载
tmux new-window -t $SESSION_NAME -n "model_download"

tmux send-keys -t $SESSION_NAME:model_download "cd <repo_directory>" Enter
tmux send-keys -t $SESSION_NAME:model_download "exec > >(tee -a .task_manager/logs/model_download.log) 2>&1" Enter

# 检查并安装 aria2c
tmux send-keys -t $SESSION_NAME:model_download "which aria2c || apt-get install -y aria2" Enter

# 部署 hfd.sh 脚本
tmux send-keys -t $SESSION_NAME:model_download "mkdir -p ~/.local/bin" Enter
tmux send-keys -t $SESSION_NAME:model_download "cp <skill_path>/scripts/hfd.sh ~/.local/bin/hfd.sh" Enter
tmux send-keys -t $SESSION_NAME:model_download "chmod +x ~/.local/bin/hfd.sh" Enter

# 根据用户选择下载模型
# 选项 1: ModelScope
tmux send-keys -t $SESSION_NAME:model_download "pip install modelscope" Enter
tmux send-keys -t $SESSION_NAME:model_download "python -c \"from modelscope import snapshot_download; snapshot_download('<model_name>')\"" Enter

# 选项 2: HuggingFace（使用 hfd.sh）
tmux send-keys -t $SESSION_NAME:model_download "~/.local/bin/hfd.sh <org/model-name> --tool aria2c -x 10" Enter

# 记录完成状态
tmux send-keys -t $SESSION_NAME:model_download "echo 'MODEL_DOWNLOAD_COMPLETE' >> .task_manager/status" Enter
tmux send-keys -t $SESSION_NAME:model_download "echo \$! > .task_manager/pids/model_download.pid" Enter
```

### 第三步：任务监控

创建监控脚本：

```bash
# 创建监控脚本
cat > <repo_directory>/.task_manager/monitor.sh << 'MONITOR_EOF'
#!/bin/bash

TASK_DIR="<repo_directory>/.task_manager"
LOG_DIR="$TASK_DIR/logs"

echo "========================================="
echo "Repo Scout 任务监控"
echo "========================================="
echo "Session: $(cat $TASK_DIR/tmux_session 2>/dev/null || echo 'N/A')"
echo "开始时间: $(cat $TASK_DIR/start_time 2>/dev/null || echo 'N/A')"
echo ""

# 检查环境搭建状态
if grep -q "ENVIRONMENT_SETUP_COMPLETE" "$TASK_DIR/status" 2>/dev/null; then
    echo "✅ 环境搭建: 完成"
else
    echo "⏳ 环境搭建: 进行中..."
    echo "   最新日志:"
    tail -n 5 "$LOG_DIR/environment.log" 2>/dev/null | sed 's/^/   /'
fi

echo ""

# 检查模型下载状态
if grep -q "MODEL_DOWNLOAD_COMPLETE" "$TASK_DIR/status" 2>/dev/null; then
    echo "✅ 模型下载: 完成"
else
    echo "⏳ 模型下载: 进行中..."
    echo "   最新日志:"
    tail -n 5 "$LOG_DIR/model_download.log" 2>/dev/null | sed 's/^/   /'
fi

echo ""
echo "========================================="
echo "监控命令:"
echo "  查看环境日志: tail -f $LOG_DIR/environment.log"
echo "  查看下载日志: tail -f $LOG_DIR/model_download.log"
echo "  进入 tmux: tmux attach -t \$(cat $TASK_DIR/tmux_session)"
echo "========================================="
MONITOR_EOF

chmod +x <repo_directory>/.task_manager/monitor.sh

# 告知用户如何监控
echo "📊 任务监控方式："
echo "1. 查看状态: bash <repo_directory>/.task_manager/monitor.sh"
echo "2. 实时日志: tail -f <repo_directory>/.task_manager/logs/environment.log"
echo "3. 进入 tmux: tmux attach -t \$SESSION_NAME"
```

### 第四步：等待并行任务完成

```bash
# 等待脚本
cat > <repo_directory>/.task_manager/wait_for_tasks.sh << 'WAIT_EOF'
#!/bin/bash

TASK_DIR="<repo_directory>/.task_manager"
TIMEOUT=3600  # 1小时超时
ELAPSED=0

echo "等待并行任务完成..."

while [ $ELAPSED -lt $TIMEOUT ]; do
    # 检查环境搭建
    ENV_DONE=false
    if grep -q "ENVIRONMENT_SETUP_COMPLETE" "$TASK_DIR/status" 2>/dev/null; then
        ENV_DONE=true
    fi
    
    # 检查模型下载
    MODEL_DONE=false
    if grep -q "MODEL_DOWNLOAD_COMPLETE" "$TASK_DIR/status" 2>/dev/null; then
        MODEL_DONE=true
    fi
    
    # 如果都完成，退出
    if [ "$ENV_DONE" = true ] && [ "$MODEL_DONE" = true ]; then
        echo "✅ 所有并行任务完成！"
        exit 0
    fi
    
    # 显示进度
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

echo "⚠️ 等待超时，请手动检查任务状态"
exit 1
WAIT_EOF

chmod +x <repo_directory>/.task_manager/wait_for_tasks.sh

# 执行等待（可后台运行）
bash <repo_directory>/.task_manager/wait_for_tasks.sh
```

### 第五步：Demo 数据准备

```bash
# 在主 window 中执行
tmux select-window -t $SESSION_NAME:0
tmux send-keys -t $SESSION_NAME "cd <repo_directory>" Enter

# 检查示例数据
if [ -d "examples" ]; then
    echo "使用 examples/ 目录中的数据"
    DATA_PATH="examples/"
elif [ -d "demo" ]; then
    echo "使用 demo/ 目录中的数据"
    DATA_PATH="demo/"
elif [ -d "assets" ]; then
    echo "使用 assets/ 目录中的数据"
    DATA_PATH="assets/"
else
    echo "未找到示例数据，请用户提供测试数据"
    # 根据模型类型创建简单测试数据
fi
```

### 第六步：推理执行

```bash
# 查找推理脚本
INFERENCE_SCRIPT=""
for script in inference.py demo.py run.py; do
    if [ -f "$script" ]; then
        INFERENCE_SCRIPT="$script"
        break
    fi
done

if [ -z "$INFERENCE_SCRIPT" ]; then
    echo "❌ 未找到推理脚本，请用户手动运行"
else
    echo "找到推理脚本: $INFERENCE_SCRIPT"
    
    # 创建输出目录
    mkdir -p .demo_output
    
    # 在新的 tmux window 中运行推理
    tmux new-window -t $SESSION_NAME -n "inference"
    tmux send-keys -t $SESSION_NAME:inference "cd <repo_directory>" Enter
    tmux send-keys -t $SESSION_NAME:inference "source .venv/bin/activate" Enter
    tmux send-keys -t $SESSION_NAME:inference "python $INFERENCE_SCRIPT --model <model_path> --input $DATA_PATH --output .demo_output/" Enter
    
    # 记录完成
    tmux send-keys -t $SESSION_NAME:inference "echo 'INFERENCE_COMPLETE' >> .task_manager/status" Enter
fi
```

### 第七步：结果验证

```bash
# 检查输出目录
if [ -d ".demo_output" ] && [ "$(ls -A .demo_output)" ]; then
    echo "✅ 推理完成！输出文件位于: .demo_output/"
    echo "输出文件列表:"
    ls -lh .demo_output/
else
    echo "⚠️ 未检测到输出文件，请检查推理日志"
fi
```

## 🛡️ 安全退出机制

### 退出钩子脚本

```bash
# 创建安全退出脚本
cat > <repo_directory>/.task_manager/cleanup.sh << 'CLEANUP_EOF'
#!/bin/bash

TASK_DIR="<repo_directory>/.task_manager"
SESSION_NAME=$(cat "$TASK_DIR/tmux_session" 2>/dev/null)

echo "正在安全停止所有后台任务..."

# 1. 停止所有记录的 PID
for pid_file in "$TASK_DIR/pids"/*.pid; do
    if [ -f "$pid_file" ]; then
        PID=$(cat "$pid_file")
        if kill -0 "$PID" 2>/dev/null; then
            echo "停止进程 $PID..."
            kill -TERM "$PID"
            sleep 2
            # 如果进程还在运行，强制杀死
            if kill -0 "$PID" 2>/dev/null; then
                kill -KILL "$PID"
            fi
        fi
    fi
done

# 2. 关闭 tmux session
if [ -n "$SESSION_NAME" ] && tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "关闭 tmux session: $SESSION_NAME"
    tmux kill-session -t "$SESSION_NAME"
fi

# 3. 清理临时文件（可选）
# rm -rf "$TASK_DIR/pids"

echo "✅ 所有任务已安全停止"
echo "日志保留在: $TASK_DIR/logs/"
CLEANUP_EOF

chmod +x <repo_directory>/.task_manager/cleanup.sh

# 设置退出钩子
trap "<repo_directory>/.task_manager/cleanup.sh" EXIT INT TERM
```

### 注册退出钩子

在脚本开始时注册：

```bash
# 在任务开始时设置
trap 'bash <repo_directory>/.task_manager/cleanup.sh' EXIT INT TERM

# 这样当脚本收到 EXIT, INT (Ctrl+C), 或 TERM 信号时，会自动执行清理
```

## 📊 任务状态查询

### 查询脚本

```bash
# 创建状态查询脚本
cat > <repo_directory>/.task_manager/status.sh << 'STATUS_EOF'
#!/bin/bash

TASK_DIR="<repo_directory>/.task_manager"

echo "========================================="
echo "Repo Scout 任务状态"
echo "========================================="

# 读取任务状态
if [ -f "$TASK_DIR/tasks.json" ]; then
    # 检查各个任务状态
    for task in environment model_download data_prep inference; do
        if grep -q "${task^^}_COMPLETE" "$TASK_DIR/status" 2>/dev/null; then
            STATUS="✅ 完成"
        elif [ -f "$TASK_DIR/pids/$task.pid" ]; then
            PID=$(cat "$TASK_DIR/pids/$task.pid")
            if kill -0 "$PID" 2>/dev/null; then
                STATUS="⏳ 运行中 (PID: $PID)"
            else
                STATUS="❌ 失败或停止"
            fi
        else
            STATUS="⏸️ 待执行"
        fi
        echo "$task: $STATUS"
    done
else
    echo "未找到任务状态文件"
fi

echo ""
echo "详细日志位于: $TASK_DIR/logs/"
STATUS_EOF

chmod +x <repo_directory>/.task_manager/status.sh

# 使用
bash <repo_directory>/.task_manager/status.sh
```

## 🔄 tmux 会话管理

### 常用命令

```bash
# 查看所有 tmux 会话
tmux ls

# 连接到指定会话
tmux attach -t <session_name>

# 临时脱离会话（任务继续运行）
# 按键: Ctrl+B, 然后按 D

# 杀死指定会话
tmux kill-session -t <session_name>

# 在会话中切换窗口
# Ctrl+B, 然后按窗口编号 (0, 1, 2...)

# 在会话中查看所有窗口
# Ctrl+B, 然后按 W
```

## 📋 完整命令记录模板

```markdown
## 调研命令记录

### 任务管理
```bash
# 初始化
SESSION_NAME="repo-scout-$(date +%Y%m%d_%H%M%S)"
tmux new-session -d -s $SESSION_NAME

# 监控
bash <repo_directory>/.task_manager/monitor.sh

# 状态查询
bash <repo_directory>/.task_manager/status.sh

# 安全退出
bash <repo_directory>/.task_manager/cleanup.sh
```

### 并行任务
```bash
# 环境搭建（window 0）
tmux new-window -t $SESSION_NAME -n "environment"
tmux send-keys -t $SESSION_NAME:environment "uv venv .venv && source .venv/bin/activate" Enter
tmux send-keys -t $SESSION_NAME:environment "uv pip install -r requirements.txt" Enter

# 模型下载（window 1）
tmux new-window -t $SESSION_NAME -n "model_download"
tmux send-keys -t $SESSION_NAME:model_download "~/.local/bin/hfd.sh <model> --tool aria2c -x 10" Enter
```

### 推理执行
```bash
# 推理（window 2）
tmux new-window -t $SESSION_NAME -n "inference"
tmux send-keys -t $SESSION_NAME:inference "source .venv/bin/activate" Enter
tmux send-keys -t $SESSION_NAME:inference "python inference.py --model <model_path> --output .demo_output/" Enter
```
```

## 🎯 最佳实践

### 1. 并行执行的判断

**应该并行的场景**：
- ✅ 环境搭建 + 模型下载（两者独立）
- ✅ 多个模型下载
- ✅ 数据准备 + 模型下载（如果数据不在模型中）

**不应该并行的场景**：
- ❌ 环境搭建 + 依赖该环境的任务
- ❌ 模型下载 + 使用该模型的推理

### 2. tmux 使用建议

- 每个长时间任务使用独立的 window
- 使用有意义的 window 名称
- 定期保存日志
- 使用日志文件而非仅依赖 tmux buffer

### 3. 错误处理

```bash
# 检查命令是否成功
tmux send-keys -t $SESSION_NAME:environment "uv pip install -r requirements.txt || echo 'INSTALL_FAILED' >> .task_manager/status" Enter

# 在等待脚本中检查
if grep -q "INSTALL_FAILED" "$TASK_DIR/status"; then
    echo "❌ 环境搭建失败"
    # 提供错误日志
    cat "$LOG_DIR/environment.log"
fi
```

## 🚨 故障排除

| 问题 | 诊断 | 解决方案 |
|------|------|----------|
| tmux session 不存在 | `tmux ls` | 重新创建 session |
| 任务卡住不动 | 检查日志文件 | 查看 `.task_manager/logs/` |
| 进程异常退出 | 检查 PID 文件 | 重新启动任务 |
| 无法连接 tmux | 权限或路径问题 | 检查 tmux socket 权限 |
| 并行任务冲突 | 资源竞争 | 调整并行策略 |

## 💡 高级用法

### 1. 远程执行

```bash
# 在远程服务器上执行
ssh user@server "tmux new-session -d -s repo-scout 'bash -c \"cd /path/to/repo && uv venv .venv && ...\"'"
```

### 2. 定时监控

```bash
# 每分钟检查一次状态
watch -n 60 'bash <repo_directory>/.task_manager/status.sh'
```

### 3. 邮件通知

```bash
# 任务完成时发送邮件
echo "Task completed" | mail -s "Repo Scout Update" user@example.com
```

## 📝 示例完整流程

```bash
# 1. 初始化
cd /workspace
git clone https://github.com/example/awesome-model.git
cd awesome-model

# 2. 设置任务管理
SESSION_NAME="repo-scout-awesome"
tmux new-session -d -s $SESSION_NAME
mkdir -p .task_manager/{logs,pids}

# 3. 并行执行环境搭建和模型下载
# Window 0: 环境
tmux send-keys -t $SESSION_NAME:0 "uv venv .venv && source .venv/bin/activate && uv pip install -r requirements.txt && echo 'ENV_DONE' >> .task_manager/status" Enter

# Window 1: 模型
tmux new-window -t $SESSION_NAME -n "model"
tmux send-keys -t $SESSION_NAME:1 "~/.local/bin/hfd.sh org/model --tool aria2c -x 10 && echo 'MODEL_DONE' >> .task_manager/status" Enter

# 4. 监控
watch -n 10 'cat .task_manager/status 2>/dev/null || echo "No status yet"'

# 5. 等待完成（在另一个终端）
while ! grep -q "ENV_DONE" .task_manager/status && ! grep -q "MODEL_DONE" .task_manager/status; do
    sleep 5
done

# 6. 运行推理
tmux new-window -t $SESSION_NAME -n "inference"
tmux send-keys -t $SESSION_NAME:inference "source .venv/bin/activate && python inference.py --model ./model --output .demo_output/" Enter

# 7. 检查结果
ls -lh .demo_output/

# 8. 清理（可选）
tmux kill-session -t $SESSION_NAME
```

## ⚠️ 注意事项

1. **tmux 依赖**：确保系统已安装 tmux
2. **权限管理**：确保 PID 文件可读写
3. **磁盘空间**：监控日志文件大小
4. **网络稳定性**：长时间下载建议使用支持断点续传的工具
5. **资源竞争**：避免过多的并行任务消耗系统资源

## 🎉 总结

通过引入 tmux 和并行执行机制，Repo Scout 现在可以：
- ⚡ 更快完成任务（并行执行）
- 🛡️ 更稳定（后台运行，不怕中断）
- 📊 更透明（实时监控和日志）
- 🔧 更灵活（随时可以检查和管理）

---

**让 AI 模型调研更快、更稳定、更可控！**
