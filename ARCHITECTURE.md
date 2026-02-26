# Repo Scout 架构说明

## 📐 工作原理

### Skill 的本质

Repo Scout skill 是一个**结构化的指导文档**，而不是一个独立的程序。它的工作方式是：

```
┌─────────────┐
│  用户请求   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────┐
│  AI Agent 加载 Skill    │
│  (读取 SKILL.md)        │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  AI Agent 理解指导原则  │
│  - 工作流程             │
│  - 最佳实践             │
│  - 决策树               │
└──────┬──────────────────┘
       │
       ▼
┌─────────────────────────┐
│  AI Agent 执行任务      │
│  - 使用工具（Bash等）   │
│  - 调用脚本             │
│  - 与用户交互           │
└─────────────────────────┘
```

**关键点**：
- ✅ Skill 提供指导原则和最佳实践
- ✅ AI Agent 根据情况智能执行
- ✅ 可以利用 AI Agent 的并行能力
- ✅ 可以调用外部脚本和工具

## 🔄 并行执行机制

### 传统串行方式

```
时间轴: ──────────────────────────────────────>

环境搭建: ████████████ (12分钟)
                      模型下载: ████████████████████ (20分钟)
                                                    推理: ████ (4分钟)
总耗时: 36分钟
```

### 增强并行方式

```
时间轴: ───────────────────────────>

环境搭建: ████████████ (12分钟)
模型下载: ████████████████████ (20分钟)
                      推理: ████ (4分钟)
总耗时: 24分钟 (节省33%)
```

### 并行实现方式

#### 1. 使用 tmux 分离执行

```bash
# Window 0: 主控制
tmux new-session -d -s repo-scout

# Window 1: 环境搭建
tmux new-window -n "environment"
tmux send-keys -t "environment" "uv venv .venv && source .venv/bin/activate" Enter

# Window 2: 模型下载（并行）
tmux new-window -n "model_download"
tmux send-keys -t "model_download" "hfd.sh model-name --tool aria2c" Enter
```

#### 2. 使用后台进程

```bash
# 后台进程 1: 环境搭建
(uv venv .venv && source .venv/bin/activate) &
PID1=$!
echo $PID1 > .task_manager/pids/environment.pid

# 后台进程 2: 模型下载（并行）
(hfd.sh model-name) &
PID2=$!
echo $PID2 > .task_manager/pids/model_download.pid

# 等待两个进程完成
wait $PID1 $PID2
```

#### 3. 使用 subagent（如果 AI Agent 支持）

```python
# 并行启动多个 subagent
task_environment = launch_subagent("setup_environment")
task_download = launch_subagent("download_model")

# 等待所有任务完成
wait_all([task_environment, task_download])
```

## 🏗️ 架构组件

### 1. 任务管理器

```
.task_manager/
├── tasks.json           # 任务配置和状态
├── status              # 完成标记
├── start_time          # 开始时间
├── tmux_session        # tmux session 名称
├── logs/               # 日志目录
│   ├── environment.log
│   ├── model_download.log
│   └── inference.log
└── pids/               # 进程 ID 目录
    ├── environment.pid
    ├── model_download.pid
    └── inference.pid
```

### 2. 核心脚本

#### init_task_manager.sh
- 创建任务管理目录结构
- 初始化 tmux session
- 设置状态跟踪文件

#### monitor.sh
- 实时显示所有任务状态
- 显示最新日志
- 提供快速命令参考

#### wait_for_tasks.sh
- 等待指定的并行任务完成
- 支持超时设置
- 显示进度指示器

#### cleanup.sh
- 安全停止所有后台进程
- 关闭 tmux session
- 保存最终状态

#### status.sh
- 简洁的任务状态查询
- 显示进度条
- 提供快速命令

### 3. 工作流程状态机

```
┌─────────┐
│  开始   │
└────┬────┘
     │
     ▼
┌─────────────────────┐
│  初始化任务管理器    │
│  - 创建目录         │
│  - 启动 tmux        │
└────┬────────────────┘
     │
     ├──────────────────┬──────────────────┐
     │                  │                  │
     ▼                  ▼                  ▼
┌─────────┐       ┌─────────┐        ┌─────────┐
│环境搭建 │       │模型下载 │        │数据准备 │
│(并行)   │       │(并行)   │        │(并行)   │
└────┬────┘       └────┬────┘        └────┬────┘
     │                  │                  │
     └──────────────────┴──────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  等待并行完成   │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   运行推理      │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │   验证结果      │
              └────────┬────────┘
                       │
                       ▼
                    ┌────┐
                    │完成│
                    └────┘
```

## 🛡️ 安全机制

### 1. 进程追踪

每个后台任务都记录其 PID：

```bash
# 启动任务时记录 PID
command &
echo $! > .task_manager/pids/task_name.pid

# 清理时使用 PID 停止进程
PID=$(cat .task_manager/pids/task_name.pid)
kill -TERM $PID
```

### 2. 退出钩子

使用 trap 捕获退出信号：

```bash
# 设置退出钩子
trap 'cleanup_function' EXIT INT TERM

# 当脚本退出、收到 INT (Ctrl+C) 或 TERM 信号时
# 自动执行清理函数
```

### 3. 状态持久化

所有任务状态都持久化到文件：

```bash
# 完成标记
echo "ENVIRONMENT_SETUP_COMPLETE" >> .task_manager/status

# 失败标记
echo "ENVIRONMENT_SETUP_FAILED" >> .task_manager/status
```

### 4. 日志分离

每个任务的日志独立保存：

```bash
# 重定向输出到日志文件
exec > >(tee -a .task_manager/logs/task.log) 2>&1
```

## 🎯 性能优化

### 1. 智能并行决策

**应该并行**：
- ✅ 独立任务（环境 vs 模型下载）
- ✅ 无依赖关系
- ✅ 资源充足

**不应并行**：
- ❌ 有依赖关系（需要环境的任务）
- ❌ 资源竞争（多个大模型下载）
- ❌ 系统资源不足

### 2. 资源管理

```bash
# 限制并行下载数
aria2c -x 10 -s 10 -k 1M  # 10个连接

# 监控系统资源
# 在并行执行时定期检查
while true; do
    CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')
    MEM=$(free | grep Mem | awk '{print $3/$2 * 100}')
    
    if [ $(echo "$CPU > 90" | bc) -eq 1 ]; then
        echo "CPU 使用率过高，暂停新任务"
        break
    fi
    
    sleep 30
done
```

### 3. 断点续传

```bash
# aria2c 支持断点续传
aria2c -c "url"  # -c 参数启用续传

# hfd.sh 内置支持
hfd.sh model-name --tool aria2c -x 10  # 自动支持续传
```

## 📊 监控和调试

### 1. 实时监控

```bash
# 方式1: 使用监控脚本
bash .task_manager/monitor.sh

# 方式2: 直接查看日志
tail -f .task_manager/logs/*.log

# 方式3: 进入 tmux
tmux attach -t session-name
```

### 2. 状态查询

```bash
# 简洁状态
bash .task_manager/status.sh

# 详细状态
cat .task_manager/tasks.json

# 完成标记
cat .task_manager/status
```

### 3. 故障排除

```bash
# 检查进程是否存活
ps aux | grep task_name

# 检查 PID 文件
ls -la .task_manager/pids/

# 查看错误日志
grep -i error .task_manager/logs/*.log
```

## 🔧 扩展和定制

### 1. 添加新任务

```bash
# 在 tasks.json 中添加
{
  "tasks": {
    "custom_task": {
      "status": "pending",
      "pid": null,
      "start_time": null,
      "end_time": null
    }
  }
}

# 创建执行脚本
tmux new-window -t $SESSION -n "custom_task"
tmux send-keys -t "$SESSION:custom_task" "your_command && echo 'CUSTOM_TASK_COMPLETE' >> .task_manager/status" Enter
```

### 2. 修改并行策略

```bash
# 根据任务类型调整并行度
PARALLEL_ENV_MODEL=true   # 环境+模型并行
PARALLEL_MULTI_MODEL=false # 多模型串行（避免资源竞争）

if [ "$PARALLEL_ENV_MODEL" = true ]; then
    # 并行执行
    start_environment_task &
    start_model_download &
    wait
else
    # 串行执行
    start_environment_task
    start_model_download
fi
```

### 3. 集成到 CI/CD

```yaml
# .github/workflows/demo.yml
name: AI Model Demo

on: [push]

jobs:
  demo:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup and Run Demo
        run: |
          # 初始化
          bash scripts/task_manager/init_task_manager.sh .
          
          # 并行执行
          bash scripts/parallel_demo.sh \
            https://github.com/user/repo.git \
            /workspace/repo \
            user/model
          
          # 检查结果
          if [ -d ".demo_output" ]; then
            echo "Demo completed successfully"
          fi
```

## 📝 最佳实践

### 1. 任务命名

使用有意义的名称：
- ✅ `environment`, `model_download`, `inference`
- ❌ `task1`, `task2`, `task3`

### 2. 错误处理

```bash
# 记录失败
command || {
    echo "TASK_FAILED" >> .task_manager/status
    echo "Error details" >> .task_manager/logs/task.log
    exit 1
}
```

### 3. 超时设置

```bash
# 设置合理的超时
TIMEOUT=3600  # 1小时

# 使用 timeout 命令
timeout $TIMEOUT long_running_command
```

### 4. 日志管理

```bash
# 定期清理旧日志
find .task_manager/logs -name "*.log" -mtime +7 -delete

# 压缩历史日志
tar -czf logs_$(date +%Y%m%d).tar.gz .task_manager/logs/*.log
```

## 🚀 总结

Repo Scout 通过以下机制实现了高效、可靠的 AI 模型调研：

1. **并行执行** - 利用 tmux 和后台进程并行处理独立任务
2. **任务管理** - 完整的状态追踪和进程管理
3. **安全机制** - 退出钩子和清理脚本确保安全退出
4. **监控体系** - 实时监控和日志记录
5. **灵活扩展** - 易于定制和集成

这些特性使得 Repo Scout 成为一个强大的 AI 模型快速调研工具！
