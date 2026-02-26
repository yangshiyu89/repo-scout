#!/bin/bash
# Repo Scout - 并行执行示例脚本
# 演示如何并行执行环境搭建和模型下载

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 参数
REPO_URL="$1"
REPO_DIR="$2"
MODEL_NAME="$3"

if [ -z "$REPO_URL" ] || [ -z "$REPO_DIR" ]; then
    echo -e "${RED}用法: $0 <repo_url> <repo_dir> [model_name]${NC}"
    echo "示例: $0 https://github.com/user/repo.git /workspace/repo user/model"
    exit 1
fi

# 默认模型名称（如果未提供）
if [ -z "$MODEL_NAME" ]; then
    MODEL_NAME="default/model"
    echo -e "${YELLOW}未指定模型名称，使用默认: $MODEL_NAME${NC}"
fi

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Repo Scout 并行执行示例              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# 1. Clone 仓库
echo -e "${BLUE}[1/6] 克隆仓库...${NC}"
git clone "$REPO_URL" "$REPO_DIR" || {
    echo -e "${RED}克隆失败${NC}"
    exit 1
}
echo -e "${GREEN}✓ 仓库克隆完成${NC}"
echo ""

# 2. 初始化任务管理器
echo -e "${BLUE}[2/6] 初始化任务管理器...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/task_manager/init_task_manager.sh" "$REPO_DIR"

# 读取 session 信息
SESSION=$(cat "$REPO_DIR/.task_manager/tmux_session")
TASK_DIR="$REPO_DIR/.task_manager"

echo -e "${GREEN}✓ 任务管理器初始化完成${NC}"
echo ""

# 3. 并行启动环境搭建和模型下载
echo -e "${BLUE}[3/6] 并行启动任务...${NC}"
echo -e "${YELLOW}启动环境搭建和模型下载（并行）${NC}"
echo ""

# 3.1 环境搭建 (Window 1)
tmux new-window -t "$SESSION" -n "environment"
tmux send-keys -t "$SESSION:environment" "cd $REPO_DIR" Enter
tmux send-keys -t "$SESSION:environment" "exec > >(tee -a .task_manager/logs/environment.log) 2>&1" Enter
tmux send-keys -t "$SESSION:environment" "echo '开始环境搭建: '$(date)" Enter

# 创建虚拟环境
tmux send-keys -t "$SESSION:environment" "uv venv .venv || { echo 'ENV_SETUP_FAILED' >> .task_manager/status; exit 1; }" Enter
sleep 1

# 激活环境
tmux send-keys -t "$SESSION:environment" "source .venv/bin/activate" Enter
sleep 1

# 安装依赖
if [ -f "$REPO_DIR/requirements.txt" ]; then
    tmux send-keys -t "$SESSION:environment" "uv pip install -r requirements.txt || { echo 'ENV_SETUP_FAILED' >> .task_manager/status; exit 1; }" Enter
elif [ -f "$REPO_DIR/setup.py" ] || [ -f "$REPO_DIR/pyproject.toml" ]; then
    tmux send-keys -t "$SESSION:environment" "uv pip install -e . || { echo 'ENV_SETUP_FAILED' >> .task_manager/status; exit 1; }" Enter
fi

# 记录完成
tmux send-keys -t "$SESSION:environment" "echo 'ENVIRONMENT_SETUP_COMPLETE' >> .task_manager/status" Enter
tmux send-keys -t "$SESSION:environment" "echo '环境搭建完成: '$(date)" Enter

echo -e "${GREEN}✓ 环境搭建任务已启动 (tmux window: environment)${NC}"

# 3.2 模型下载 (Window 2)
tmux new-window -t "$SESSION" -n "model_download"
tmux send-keys -t "$SESSION:model_download" "cd $REPO_DIR" Enter
tmux send-keys -t "$SESSION:model_download" "exec > >(tee -a .task_manager/logs/model_download.log) 2>&1" Enter
tmux send-keys -t "$SESSION:model_download" "echo '开始模型下载: '$(date)" Enter

# 检查并安装 aria2c
tmux send-keys -t "$SESSION:model_download" "which aria2c || { apt-get update && apt-get install -y aria2; }" Enter
sleep 2

# 部署 hfd.sh
tmux send-keys -t "$SESSION:model_download" "mkdir -p ~/.local/bin" Enter
tmux send-keys -t "$SESSION:model_download" "cp $SCRIPT_DIR/hfd.sh ~/.local/bin/hfd.sh && chmod +x ~/.local/bin/hfd.sh" Enter

# 下载模型
tmux send-keys -t "$SESSION:model_download" "~/.local/bin/hfd.sh $MODEL_NAME --tool aria2c -x 10 || { echo 'MODEL_DOWNLOAD_FAILED' >> .task_manager/status; exit 1; }" Enter

# 记录完成
tmux send-keys -t "$SESSION:model_download" "echo 'MODEL_DOWNLOAD_COMPLETE' >> .task_manager/status" Enter
tmux send-keys -t "$SESSION:model_download" "echo '模型下载完成: '$(date)" Enter

echo -e "${GREEN}✓ 模型下载任务已启动 (tmux window: model_download)${NC}"
echo ""

# 4. 等待并行任务完成
echo -e "${BLUE}[4/6] 等待并行任务完成...${NC}"
echo -e "${YELLOW}这可能需要几分钟到几小时，取决于依赖和模型大小${NC}"
echo -e "${CYAN}提示: 你可以按 Ctrl+C 暂停等待，任务会在后台继续运行${NC}"
echo ""

# 设置退出钩子
cleanup() {
    echo ""
    echo -e "${YELLOW}收到中断信号，但任务仍在后台运行${NC}"
    echo -e "${BLUE}使用以下命令重新监控:${NC}"
    echo "  bash $TASK_DIR/monitor.sh"
    exit 0
}

trap cleanup INT TERM

# 等待任务完成
bash "$TASK_DIR/wait_for_tasks.sh" "$TASK_DIR" 3600 10

# 5. 数据准备
echo ""
echo -e "${BLUE}[5/6] 准备测试数据...${NC}"

# 检查是否有示例数据
if [ -d "$REPO_DIR/examples" ]; then
    DATA_PATH="$REPO_DIR/examples"
    echo -e "${GREEN}✓ 使用 examples/ 目录中的数据${NC}"
elif [ -d "$REPO_DIR/demo" ]; then
    DATA_PATH="$REPO_DIR/demo"
    echo -e "${GREEN}✓ 使用 demo/ 目录中的数据${NC}"
elif [ -d "$REPO_DIR/assets" ]; then
    DATA_PATH="$REPO_DIR/assets"
    echo -e "${GREEN}✓ 使用 assets/ 目录中的数据${NC}"
else
    echo -e "${YELLOW}⚠ 未找到示例数据，请用户提供测试数据${NC}"
    DATA_PATH="<请指定数据路径>"
fi

# 记录数据准备完成
echo "DATA_PREP_COMPLETE" >> "$TASK_DIR/status"

# 6. 运行推理
echo ""
echo -e "${BLUE}[6/6] 查找并运行推理脚本...${NC}"

# 查找推理脚本
INFERENCE_SCRIPT=""
for script in inference.py demo.py run.py; do
    if [ -f "$REPO_DIR/$script" ]; then
        INFERENCE_SCRIPT="$script"
        break
    fi
done

if [ -z "$INFERENCE_SCRIPT" ]; then
    echo -e "${YELLOW}⚠ 未找到标准推理脚本${NC}"
    echo -e "${BLUE}请手动运行推理${NC}"
else
    echo -e "${GREEN}✓ 找到推理脚本: $INFERENCE_SCRIPT${NC}"
    
    # 创建输出目录
    mkdir -p "$REPO_DIR/.demo_output"
    
    # 在新 window 中运行推理
    tmux new-window -t "$SESSION" -n "inference"
    tmux send-keys -t "$SESSION:inference" "cd $REPO_DIR" Enter
    tmux send-keys -t "$SESSION:inference" "exec > >(tee -a .task_manager/logs/inference.log) 2>&1" Enter
    tmux send-keys -t "$SESSION:inference" "source .venv/bin/activate" Enter
    
    # 运行推理（需要根据实际脚本调整参数）
    tmux send-keys -t "$SESSION:inference" "python $INFERENCE_SCRIPT --model ./$(basename $MODEL_NAME) --input $DATA_PATH --output .demo_output/" Enter
    
    # 记录完成
    tmux send-keys -t "$SESSION:inference" "echo 'INFERENCE_COMPLETE' >> .task_manager/status" Enter
    
    echo -e "${GREEN}✓ 推理任务已启动 (tmux window: inference)${NC}"
    echo -e "${CYAN}提示: 使用 'tmux attach -t $SESSION' 查看推理进度${NC}"
fi

# 完成总结
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    🎉 并行执行已启动！                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}任务信息${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "仓库: ${CYAN}$REPO_DIR${NC}"
echo -e "模型: ${CYAN}$MODEL_NAME${NC}"
echo -e "Session: ${CYAN}$SESSION${NC}"
echo -e "任务目录: ${CYAN}$TASK_DIR${NC}"
echo ""
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "${BLUE}监控命令${NC}"
echo -e "${BLUE}═════════════════════════════════════════${NC}"
echo -e "查看状态: ${GREEN}bash $TASK_DIR/status.sh${NC}"
echo -e "详细监控: ${GREEN}bash $TASK_DIR/monitor.sh${NC}"
echo -e "进入 tmux: ${GREEN}tmux attach -t $SESSION${NC}"
echo -e "查看日志: ${GREEN}tail -f $TASK_DIR/logs/*.log${NC}"
echo -e "安全清理: ${GREEN}bash $TASK_DIR/cleanup.sh${NC}"
echo ""
echo -e "${YELLOW}提示: 任务正在后台运行，你可以安全地退出此脚本${NC}"
