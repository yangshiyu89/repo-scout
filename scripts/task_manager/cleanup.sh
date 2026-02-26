#!/bin/bash
# Repo Scout - 安全清理脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 参数检查
if [ -z "$1" ]; then
    if [ -f /tmp/repo_scout_task_dir ]; then
        TASK_DIR=$(cat /tmp/repo_scout_task_dir)
    else
        echo -e "${RED}错误: 请提供任务目录路径${NC}"
        echo "用法: $0 <task_directory>"
        exit 1
    fi
else
    TASK_DIR="$1"
fi

# 检查任务目录是否存在
if [ ! -d "$TASK_DIR" ]; then
    echo -e "${RED}错误: 任务目录不存在: $TASK_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Repo Scout 安全清理                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# 1. 停止所有记录的进程
echo -e "${YELLOW}[1/4] 停止后台进程...${NC}"
PID_DIR="$TASK_DIR/pids"
STOPPED_COUNT=0

for pid_file in "$PID_DIR"/*.pid; do
    if [ -f "$pid_file" ]; then
        PID=$(cat "$pid_file")
        TASK_NAME=$(basename "$pid_file" .pid)
        
        if kill -0 "$PID" 2>/dev/null; then
            echo -e "  停止 $TASK_NAME (PID: $PID)..."
            kill -TERM "$PID" 2>/dev/null
            sleep 2
            
            # 如果进程还在运行，强制杀死
            if kill -0 "$PID" 2>/dev/null; then
                echo -e "  ${YELLOW}进程未响应，强制终止...${NC}"
                kill -KILL "$PID" 2>/dev/null
                sleep 1
            fi
            
            if kill -0 "$PID" 2>/dev/null; then
                echo -e "  ${RED}❌ 无法停止进程 $PID${NC}"
            else
                echo -e "  ${GREEN}✅ 已停止 $TASK_NAME${NC}"
                ((STOPPED_COUNT++))
            fi
        else
            echo -e "  ${BLUE}ℹ️  进程 $PID 已不存在${NC}"
        fi
    fi
done

if [ "$STOPPED_COUNT" -eq 0 ]; then
    echo -e "  ${BLUE}没有运行中的进程${NC}"
fi

# 2. 关闭 tmux session
echo ""
echo -e "${YELLOW}[2/4] 关闭 tmux session...${NC}"
SESSION_FILE="$TASK_DIR/tmux_session"

if [ -f "$SESSION_FILE" ]; then
    SESSION=$(cat "$SESSION_FILE")
    
    if tmux has-session -t "$SESSION" 2>/dev/null; then
        echo -e "  关闭 session: $SESSION"
        tmux kill-session -t "$SESSION" 2>/dev/null
        
        if tmux has-session -t "$SESSION" 2>/dev/null; then
            echo -e "  ${RED}❌ 无法关闭 tmux session${NC}"
        else
            echo -e "  ${GREEN}✅ tmux session 已关闭${NC}"
        fi
    else
        echo -e "  ${BLUE}ℹ️  tmux session 已不存在${NC}"
    fi
else
    echo -e "  ${BLUE}ℹ️  未找到 tmux session 记录${NC}"
fi

# 3. 保存最终状态
echo ""
echo -e "${YELLOW}[3/4] 保存最终状态...${NC}"
STATUS_FILE="$TASK_DIR/status"
if [ -f "$STATUS_FILE" ]; then
    echo "CLEANUP_COMPLETED_AT=$(date '+%Y-%m-%d %H:%M:%S')" >> "$STATUS_FILE"
    echo -e "  ${GREEN}✅ 状态已保存${NC}"
fi

# 4. 显示清理摘要
echo ""
echo -e "${YELLOW}[4/4] 清理摘要${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "停止的进程: ${GREEN}$STOPPED_COUNT${NC}"
echo -e "任务目录: ${BLUE}$TASK_DIR${NC}"
echo -e "日志保留: ${BLUE}$TASK_DIR/logs/${NC}"
echo ""

# 询问是否删除任务目录
echo -e "${YELLOW}是否删除任务目录？ (包含日志) [y/N]${NC}"
read -r -t 10 RESPONSE

if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}删除任务目录...${NC}"
    rm -rf "$TASK_DIR"
    echo -e "${GREEN}✅ 任务目录已删除${NC}"
else
    echo -e "${BLUE}ℹ️  保留任务目录和日志${NC}"
    echo -e "日志位置: $TASK_DIR/logs/"
fi

# 清理临时文件
rm -f /tmp/repo_scout_session /tmp/repo_scout_task_dir

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    ✅ 清理完成                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
