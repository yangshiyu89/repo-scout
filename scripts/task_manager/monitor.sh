#!/bin/bash
# Repo Scout - 任务监控脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 参数检查
if [ -z "$1" ]; then
    # 尝试从环境变量或临时文件读取
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

LOG_DIR="$TASK_DIR/logs"
STATUS_FILE="$TASK_DIR/status"

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Repo Scout 任务监控面板           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# 显示基本信息
if [ -f "$TASK_DIR/tmux_session" ]; then
    SESSION=$(cat "$TASK_DIR/tmux_session")
    echo -e "${BLUE}Session:${NC} $SESSION"
fi

if [ -f "$TASK_DIR/start_time" ]; then
    START=$(cat "$TASK_DIR/start_time")
    echo -e "${BLUE}开始时间:${NC} $START"
fi

echo ""
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}任务状态${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"

# 检查环境搭建状态
echo -e "${YELLOW}【环境搭建】${NC}"
if grep -q "ENVIRONMENT_SETUP_COMPLETE" "$STATUS_FILE" 2>/dev/null; then
    echo -e "  状态: ${GREEN}✅ 完成${NC}"
elif [ -f "$TASK_DIR/pids/environment.pid" ]; then
    PID=$(cat "$TASK_DIR/pids/environment.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "  状态: ${YELLOW}⏳ 运行中 (PID: $PID)${NC}"
    else
        echo -e "  状态: ${RED}❌ 已停止${NC}"
    fi
else
    echo -e "  状态: ${BLUE}⏸️ 待执行${NC}"
fi

if [ -f "$LOG_DIR/environment.log" ]; then
    echo -e "  ${CYAN}最新日志:${NC}"
    tail -n 3 "$LOG_DIR/environment.log" | sed 's/^/    /'
fi
echo ""

# 检查模型下载状态
echo -e "${YELLOW}【模型下载】${NC}"
if grep -q "MODEL_DOWNLOAD_COMPLETE" "$STATUS_FILE" 2>/dev/null; then
    echo -e "  状态: ${GREEN}✅ 完成${NC}"
elif [ -f "$TASK_DIR/pids/model_download.pid" ]; then
    PID=$(cat "$TASK_DIR/pids/model_download.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "  状态: ${YELLOW}⏳ 运行中 (PID: $PID)${NC}"
    else
        echo -e "  状态: ${RED}❌ 已停止${NC}"
    fi
else
    echo -e "  状态: ${BLUE}⏸️ 待执行${NC}"
fi

if [ -f "$LOG_DIR/model_download.log" ]; then
    echo -e "  ${CYAN}最新日志:${NC}"
    tail -n 3 "$LOG_DIR/model_download.log" | sed 's/^/    /'
fi
echo ""

# 检查数据准备状态
echo -e "${YELLOW}【数据准备】${NC}"
if grep -q "DATA_PREP_COMPLETE" "$STATUS_FILE" 2>/dev/null; then
    echo -e "  状态: ${GREEN}✅ 完成${NC}"
elif [ -f "$TASK_DIR/pids/data_prep.pid" ]; then
    PID=$(cat "$TASK_DIR/pids/data_prep.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "  状态: ${YELLOW}⏳ 运行中 (PID: $PID)${NC}"
    else
        echo -e "  状态: ${RED}❌ 已停止${NC}"
    fi
else
    echo -e "  状态: ${BLUE}⏸️ 待执行${NC}"
fi
echo ""

# 检查推理状态
echo -e "${YELLOW}【推理执行】${NC}"
if grep -q "INFERENCE_COMPLETE" "$STATUS_FILE" 2>/dev/null; then
    echo -e "  状态: ${GREEN}✅ 完成${NC}"
elif [ -f "$TASK_DIR/pids/inference.pid" ]; then
    PID=$(cat "$TASK_DIR/pids/inference.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "  状态: ${YELLOW}⏳ 运行中 (PID: $PID)${NC}"
    else
        echo -e "  状态: ${RED}❌ 已停止${NC}"
    fi
else
    echo -e "  状态: ${BLUE}⏸️ 待执行${NC}"
fi

if [ -f "$LOG_DIR/inference.log" ]; then
    echo -e "  ${CYAN}最新日志:${NC}"
    tail -n 3 "$LOG_DIR/inference.log" | sed 's/^/    /'
fi
echo ""

echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}快速命令${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${CYAN}查看环境日志:${NC}   tail -f $LOG_DIR/environment.log"
echo -e "${CYAN}查看下载日志:${NC}   tail -f $LOG_DIR/model_download.log"
echo -e "${CYAN}查看推理日志:${NC}   tail -f $LOG_DIR/inference.log"
if [ -f "$TASK_DIR/tmux_session" ]; then
    SESSION=$(cat "$TASK_DIR/tmux_session")
    echo -e "${CYAN}进入 tmux:${NC}       tmux attach -t $SESSION"
fi
echo -e "${CYAN}清理任务:${NC}       bash $TASK_DIR/cleanup.sh"
echo ""

# 计算总体进度
TOTAL=4
COMPLETE=$(grep -c "_COMPLETE" "$STATUS_FILE" 2>/dev/null || echo 0)
PROGRESS=$((COMPLETE * 100 / TOTAL))

echo -e "${BLUE}总体进度: ${GREEN}$PROGRESS%${NC} ($COMPLETE/$TOTAL)"
echo ""

# 如果所有任务完成，显示完成消息
if [ "$COMPLETE" -eq "$TOTAL" ]; then
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║    🎉 所有任务已完成！                 ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
fi
