#!/bin/bash
# Repo Scout - 任务管理器初始化脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 参数检查
if [ -z "$1" ]; then
    echo -e "${RED}错误: 请提供仓库目录路径${NC}"
    echo "用法: $0 <repo_directory>"
    exit 1
fi

REPO_DIR="$1"
TASK_DIR="$REPO_DIR/.task_manager"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Repo Scout 任务管理器初始化${NC}"
echo -e "${BLUE}=========================================${NC}"

# 创建目录结构
echo -e "${YELLOW}创建任务管理目录...${NC}"
mkdir -p "$TASK_DIR"
mkdir -p "$TASK_DIR/logs"
mkdir -p "$TASK_DIR/pids"

# 初始化任务状态文件
echo -e "${YELLOW}初始化任务状态文件...${NC}"
REPO_NAME=$(basename "$REPO_DIR")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

cat > "$TASK_DIR/tasks.json" << EOF
{
  "repo_name": "$REPO_NAME",
  "repo_path": "$REPO_DIR",
  "start_time": "$TIMESTAMP",
  "tasks": {
    "environment": {
      "status": "pending",
      "pid": null,
      "start_time": null,
      "end_time": null
    },
    "model_download": {
      "status": "pending",
      "pid": null,
      "start_time": null,
      "end_time": null
    },
    "data_prep": {
      "status": "pending",
      "pid": null,
      "start_time": null,
      "end_time": null
    },
    "inference": {
      "status": "pending",
      "pid": null,
      "start_time": null,
      "end_time": null
    }
  }
}
EOF

# 创建状态文件
touch "$TASK_DIR/status"

# 记录开始时间
echo "$TIMESTAMP" > "$TASK_DIR/start_time"

# 检查并安装 tmux
if ! command -v tmux &> /dev/null; then
    echo -e "${YELLOW}tmux 未安装，正在安装...${NC}"
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y tmux
    elif command -v brew &> /dev/null; then
        brew install tmux
    else
        echo -e "${RED}无法自动安装 tmux，请手动安装${NC}"
        exit 1
    fi
fi

# 创建 tmux session
SESSION_NAME="repo-scout-$(date +%Y%m%d_%H%M%S)"
echo "$SESSION_NAME" > "$TASK_DIR/tmux_session"

echo -e "${YELLOW}创建 tmux session: $SESSION_NAME${NC}"
tmux new-session -d -s "$SESSION_NAME" -c "$REPO_DIR"

# 设置窗口名称
tmux rename-window -t "$SESSION_NAME:0" 'main'

echo -e "${GREEN}✅ 任务管理器初始化完成！${NC}"
echo ""
echo -e "${BLUE}Session 名称: ${NC}$SESSION_NAME"
echo -e "${BLUE}任务目录: ${NC}$TASK_DIR"
echo -e "${BLUE}日志目录: ${NC}$TASK_DIR/logs"
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}常用命令:${NC}"
echo -e "  监控任务: ${GREEN}bash $TASK_DIR/monitor.sh${NC}"
echo -e "  查看状态: ${GREEN}bash $TASK_DIR/status.sh${NC}"
echo -e "  进入 tmux: ${GREEN}tmux attach -t $SESSION_NAME${NC}"
echo -e "  清理任务: ${GREEN}bash $TASK_DIR/cleanup.sh${NC}"
echo -e "${BLUE}=========================================${NC}"

# 导出环境变量供后续使用
export REPO_SCOUT_SESSION="$SESSION_NAME"
export REPO_SCOUT_TASK_DIR="$TASK_DIR"
echo "$SESSION_NAME" > /tmp/repo_scout_session
echo "$TASK_DIR" > /tmp/repo_scout_task_dir
