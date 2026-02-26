#!/bin/bash
# 完整集成示例 - 测试中断恢复功能

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
    echo ""
    echo "示例:"
    echo "  # 首次执行"
    echo "  $0 https://github.com/user/repo.git /workspace/repo user/model"
    echo ""
    echo "  # 中断后恢复执行（自动跳过已完成任务）"
    echo "  $0 https://github.com/user/repo.git /workspace/repo user/model"
    exit 1
fi

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Repo Scout - 完整集成示例            ║${NC}"
echo -e "${CYAN}║   支持中断恢复                         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# 检查是否已经初始化
if [ -d "$REPO_DIR/.task_manager" ]; then
    echo -e "${YELLOW}⚠️  检测到已有任务管理器${NC}"
    echo ""
    
    # 分析当前进度
    bash scripts/task_manager/resume_manager.sh analyze "$REPO_DIR"
    
    echo ""
    echo -e "${YELLOW}是否从上次进度恢复？ [Y/n]${NC}"
    read -r CONFIRM
    
    if [[ ! "$CONFIRM" =~ ^[Nn]$ ]]; then
        # 恢复执行
        bash scripts/task_manager/resume_manager.sh resume "$REPO_DIR"
        exit $?
    fi
    
    echo -e "${BLUE}将从头开始执行...${NC}"
fi

# 初始化任务管理器
echo ""
echo -e "${BLUE}[1/5] 初始化任务管理器...${NC}"
bash scripts/task_manager/init_task_manager.sh "$REPO_DIR"

SESSION=$(cat "$REPO_DIR/.task_manager/tmux_session" 2>/dev/null)
TASK_DIR="$REPO_DIR/.task_manager"

# 从模板创建任务文件
echo -e "${BLUE}[2/5] 创建任务定义...${NC}"
python3 << PYTHON_EOF
import json
import shutil

# 读取模板
with open('templates/tasks_template.json', 'r') as f:
    template = json.load(f)

# 替换变量
template['project_info']['repo_url'] = '$REPO_URL'
template['project_info']['repo_path'] = '$REPO_DIR'
template['project_info']['model_name'] = '$MODEL_NAME'
template['project_info']['repo_name'] = '$REPO_URL'.split('/')[-1].replace('.git', '')

# 保存
with open('$TASK_DIR/tasks.json', 'w') as f:
    json.dump(template, f, indent=2)

print("✓ 任务定义已创建")
PYTHON_EOF

# 初始化进度文件
echo -e "${BLUE}[3/5] 初始化进度跟踪...${NC}"
python3 << PYTHON_EOF
import json
from datetime import datetime

# 读取任务定义
with open('$TASK_DIR/tasks.json', 'r') as f:
    tasks_data = json.load(f)

# 创建进度文件
progress = {
    "initialized_at": datetime.now().isoformat(),
    "last_updated": datetime.now().isoformat(),
    "overall_status": "in_progress",
    "completed_count": 0,
    "total_count": len(tasks_data['tasks']),
    "tasks": {}
}

with open('$TASK_DIR/progress.json', 'w') as f:
    json.dump(progress, f, indent=2)

print(f"✓ 进度文件已初始化 ({progress['total_count']} 个任务)")
PYTHON_EOF

# 执行任务（带恢复逻辑）
echo ""
echo -e "${BLUE}[4/5] 开始执行任务...${NC}"
echo ""

# 任务 1: Clone 仓库
TASK_ID="task_001"
if ! bash scripts/task_manager/progress_manager.sh is-completed "$TASK_ID" 2>/dev/null; then
    echo -e "${CYAN}执行: Clone 仓库${NC}"
    bash scripts/task_manager/progress_manager.sh start "$TASK_ID" "Clone Repository"
    
    if [ ! -d "$REPO_DIR" ]; then
        git clone "$REPO_URL" "$REPO_DIR"
    else
        echo "仓库已存在，跳过克隆"
    fi
    
    # 验证
    if [ -d "$REPO_DIR/.git" ]; then
        bash scripts/task_manager/task_validator.sh run "$TASK_ID" directory_exists "$REPO_DIR/.git"
        bash scripts/task_manager/progress_manager.sh complete "$TASK_ID"
        echo -e "${GREEN}✓ Clone 完成${NC}"
    else
        bash scripts/task_manager/progress_manager.sh fail "$TASK_ID" "Clone 失败"
        exit 1
    fi
else
    echo -e "${GREEN}✓ 跳过已完成: Clone 仓库${NC}"
fi
echo ""

# 任务 2: 分析依赖
TASK_ID="task_002"
if ! bash scripts/task_manager/progress_manager.sh is-completed "$TASK_ID" 2>/dev/null; then
    echo -e "${CYAN}执行: 分析依赖${NC}"
    bash scripts/task_manager/progress_manager.sh start "$TASK_ID" "Analyze Dependencies"
    
    cd "$REPO_DIR"
    
    # 检查依赖文件
    DEP_FILES=""
    [ -f "requirements.txt" ] && DEP_FILES="$DEP_FILES requirements.txt"
    [ -f "setup.py" ] && DEP_FILES="$DEP_FILES setup.py"
    [ -f "pyproject.toml" ] && DEP_FILES="$DEP_FILES pyproject.toml"
    
    # 更新任务输出
    python3 << PYTHON_UPDATE
import json
with open('$TASK_DIR/tasks.json', 'r') as f:
    data = json.load(f)
for task in data['tasks']:
    if task['id'] == '$TASK_ID':
        task['output']['dependencies'] = '$DEP_FILES'.split()
        break
with open('$TASK_DIR/tasks.json', 'w') as f:
    json.dump(data, f, indent=2)
PYTHON_UPDATE
    
    bash scripts/task_manager/progress_manager.sh verify "$TASK_ID" "true"
    bash scripts/task_manager/progress_manager.sh complete "$TASK_ID"
    echo -e "${GREEN}✓ 分析完成${NC}"
else
    echo -e "${GREEN}✓ 跳过已完成: 分析依赖${NC}"
fi
echo ""

# 任务 3: 创建虚拟环境
TASK_ID="task_003"
if ! bash scripts/task_manager/progress_manager.sh is-completed "$TASK_ID" 2>/dev/null; then
    echo -e "${CYAN}执行: 创建虚拟环境${NC}"
    bash scripts/task_manager/progress_manager.sh start "$TASK_ID" "Create Virtual Environment"
    
    cd "$REPO_DIR"
    uv venv .venv
    
    # 验证
    if [ -f "$REPO_DIR/.venv/bin/python" ]; then
        bash scripts/task_manager/task_validator.sh run "$TASK_ID" directory_exists "$REPO_DIR/.venv"
        bash scripts/task_manager/progress_manager.sh complete "$TASK_ID"
        echo -e "${GREEN}✓ 虚拟环境创建完成${NC}"
    else
        bash scripts/task_manager/progress_manager.sh fail "$TASK_ID" "创建虚拟环境失败"
        exit 1
    fi
else
    echo -e "${GREEN}✓ 跳过已完成: 创建虚拟环境${NC}"
fi
echo ""

# 任务 4: 安装依赖
TASK_ID="task_004"
if ! bash scripts/task_manager/progress_manager.sh is-completed "$TASK_ID" 2>/dev/null; then
    echo -e "${CYAN}执行: 安装依赖${NC}"
    bash scripts/task_manager/progress_manager.sh start "$TASK_ID" "Install Dependencies"
    
    cd "$REPO_DIR"
    source .venv/bin/activate
    
    if [ -f "requirements.txt" ]; then
        uv pip install -r requirements.txt
    elif [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        uv pip install -e .
    fi
    
    bash scripts/task_manager/progress_manager.sh verify "$TASK_ID" "true"
    bash scripts/task_manager/progress_manager.sh complete "$TASK_ID"
    echo -e "${GREEN}✓ 依赖安装完成${NC}"
else
    echo -e "${GREEN}✓ 跳过已完成: 安装依赖${NC}"
fi
echo ""

# 显示最终状态
echo -e "${BLUE}[5/5] 生成执行报告...${NC}"
bash scripts/task_manager/progress_manager.sh show

# 恢复提示
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   💡 中断恢复提示                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "如果执行中断，可以重新运行此脚本："
echo ""
echo -e "${GREEN}  $0 '$REPO_URL' '$REPO_DIR' '$MODEL_NAME'${NC}"
echo ""
echo "脚本会自动："
echo "  1. 检测已完成的任务"
echo "  2. 跳过已完成的任务"
echo "  3. 从中断点继续执行"
echo ""
echo "或者使用恢复管理器："
echo ""
echo -e "${GREEN}  # 查看当前进度"
echo -e "  bash scripts/task_manager/resume_manager.sh status '$REPO_DIR'${NC}"
echo ""
echo -e "${GREEN}  # 从中断点恢复"
echo -e "  bash scripts/task_manager/resume_manager.sh resume '$REPO_DIR'${NC}"
echo ""
