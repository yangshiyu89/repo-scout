#!/bin/bash
# Repo Scout - 等待并行任务完成脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 参数
TASK_DIR="${1:-$(cat /tmp/repo_scout_task_dir 2>/dev/null)}"
TIMEOUT="${2:-3600}"  # 默认 1 小时超时
CHECK_INTERVAL="${3:-10}"  # 默认每 10 秒检查一次

if [ -z "$TASK_DIR" ]; then
    echo -e "${RED}错误: 请提供任务目录路径${NC}"
    echo "用法: $0 <task_directory> [timeout_seconds] [check_interval]"
    exit 1
fi

STATUS_FILE="$TASK_DIR/status"

if [ ! -f "$STATUS_FILE" ]; then
    echo -e "${RED}错误: 状态文件不存在${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     等待并行任务完成                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}超时时间: ${NC}$TIMEOUT 秒"
echo -e "${BLUE}检查间隔: ${NC}$CHECK_INTERVAL 秒"
echo ""

ELAPSED=0
DOT_COUNT=0

# 定义需要等待的任务
REQUIRED_TASKS=("ENVIRONMENT_SETUP_COMPLETE" "MODEL_DOWNLOAD_COMPLETE")
TOTAL_REQUIRED=${#REQUIRED_TASKS[@]}

while [ $ELAPSED -lt $TIMEOUT ]; do
    # 检查所有必需任务是否完成
    COMPLETE_COUNT=0
    for task in "${REQUIRED_TASKS[@]}"; do
        if grep -q "$task" "$STATUS_FILE" 2>/dev/null; then
            ((COMPLETE_COUNT++))
        fi
    done
    
    # 如果所有任务都完成
    if [ $COMPLETE_COUNT -eq $TOTAL_REQUIRED ]; then
        echo ""
        echo ""
        echo -e "${GREEN}✅ 所有并行任务已完成！${NC}"
        echo -e "${GREEN}完成时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo ""
        
        # 显示完成状态
        echo -e "${BLUE}═════════════════════════════════════════${NC}"
        echo -e "${BLUE}任务完成状态:${NC}"
        for task in "${REQUIRED_TASKS[@]}"; do
            echo -e "  ${GREEN}✓${NC} ${task/_COMPLETE/}"
        done
        echo -e "${BLUE}═════════════════════════════════════════${NC}"
        
        exit 0
    fi
    
    # 显示进度
    echo -ne "${YELLOW}等待中 [${COMPLETE_COUNT}/${TOTAL_REQUIRED}]${NC}"
    
    # 动画点
    case $DOT_COUNT in
        0) echo -n "." ;;
        1) echo -n ".." ;;
        2) echo -n "..." ;;
        3) echo -n "   " ;;
    esac
    echo -ne "\r"
    
    DOT_COUNT=$(( (DOT_COUNT + 1) % 4 ))
    
    sleep $CHECK_INTERVAL
    ELAPSED=$((ELAPSED + CHECK_INTERVAL))
    
    # 每 30 秒显示一次已等待时间
    if [ $((ELAPSED % 30)) -eq 0 ]; then
        echo -ne "\r${BLUE}已等待: ${ELAPSED}秒${NC}                    \n"
    fi
done

# 超时处理
echo ""
echo ""
echo -e "${RED}⚠️  等待超时 (${TIMEOUT}秒)${NC}"
echo ""
echo -e "${YELLOW}建议操作:${NC}"
echo "1. 检查任务状态: bash $TASK_DIR/monitor.sh"
echo "2. 查看日志文件: ls -lh $TASK_DIR/logs/"
echo "3. 手动检查进程: ps aux | grep repo-scout"
echo ""

# 显示哪些任务未完成
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}未完成的任务:${NC}"
for task in "${REQUIRED_TASKS[@]}"; do
    if ! grep -q "$task" "$STATUS_FILE" 2>/dev/null; then
        echo -e "  ${RED}✗${NC} ${task/_COMPLETE/}"
    fi
done
echo -e "${BLUE}═════════════════════════════════════════${NC}"

exit 1
