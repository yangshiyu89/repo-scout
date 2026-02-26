#!/bin/bash
# Repo Scout - 简洁状态查询脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 参数检查
TASK_DIR="${1:-$(cat /tmp/repo_scout_task_dir 2>/dev/null)}"

if [ -z "$TASK_DIR" ]; then
    echo -e "${RED}错误: 请提供任务目录路径${NC}"
    echo "用法: $0 <task_directory>"
    exit 1
fi

STATUS_FILE="$TASK_DIR/status"

if [ ! -d "$TASK_DIR" ]; then
    echo -e "${RED}错误: 任务目录不存在${NC}"
    exit 1
fi

# 获取 session 信息
SESSION=$(cat "$TASK_DIR/tmux_session" 2>/dev/null || echo "N/A")
START_TIME=$(cat "$TASK_DIR/start_time" 2>/dev/null || echo "N/A")

echo -e "${BLUE}Repo Scout 任务状态${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "Session: ${CYAN}$SESSION${NC}"
echo -e "开始: ${CYAN}$START_TIME${NC}"
echo ""

# 任务状态映射
declare -A TASK_STATUS=(
    ["ENVIRONMENT_SETUP_COMPLETE"]="环境搭建"
    ["MODEL_DOWNLOAD_COMPLETE"]="模型下载"
    ["DATA_PREP_COMPLETE"]="数据准备"
    ["INFERENCE_COMPLETE"]="推理执行"
)

# 检查每个任务
for task_complete in "${!TASK_STATUS[@]}"; do
    task_name="${TASK_STATUS[$task_complete]}"
    task_id="${task_complete/_COMPLETE/}"
    task_id_lower=$(echo "$task_id" | tr '[:upper:]' '[:lower:]')
    
    # 检查是否完成
    if grep -q "$task_complete" "$STATUS_FILE" 2>/dev/null; then
        echo -e "$task_name: ${GREEN}✅ 完成${NC}"
    # 检查是否有 PID 运行
    elif [ -f "$TASK_DIR/pids/${task_id_lower}.pid" ]; then
        PID=$(cat "$TASK_DIR/pids/${task_id_lower}.pid")
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "$task_name: ${YELLOW}⏳ 运行中${NC} (PID: $PID)"
        else
            echo -e "$task_name: ${RED}❌ 已停止${NC}"
        fi
    else
        echo -e "$task_name: ${BLUE}⏸️  待执行${NC}"
    fi
done

echo -e "${BLUE}═════════════════════════════════════════${NC}"

# 计算进度
TOTAL=${#TASK_STATUS[@]}
COMPLETE=$(grep -c "_COMPLETE" "$STATUS_FILE" 2>/dev/null || echo 0)
PROGRESS=$((COMPLETE * 100 / TOTAL))

# 进度条
FILLED=$((PROGRESS / 2))
EMPTY=$((50 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

echo -e "进度: [${GREEN}${BAR}${NC}] ${PROGRESS}%"
echo ""

# 显示快速命令
echo -e "${BLUE}快速命令:${NC}"
echo "  监控: bash $TASK_DIR/monitor.sh"
if [ "$SESSION" != "N/A" ]; then
    echo "  进入: tmux attach -t $SESSION"
fi
echo "  清理: bash $TASK_DIR/cleanup.sh"
