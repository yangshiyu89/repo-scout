#!/bin/bash
# Repo Scout - 进度跟踪管理器

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 进度文件
PROGRESS_FILE="${1:-.task_manager/progress.json}"
TASKS_FILE="${2:-.task_manager/tasks.json}"

# 初始化进度文件
init_progress() {
    if [ ! -f "$PROGRESS_FILE" ]; then
        cat > "$PROGRESS_FILE" << 'EOF'
{
  "initialized_at": "<TIMESTAMP>",
  "last_updated": "<TIMESTAMP>",
  "overall_status": "in_progress",
  "completed_count": 0,
  "total_count": 0,
  "tasks": {}
}
EOF
        # 替换时间戳
        TIMESTAMP=$(date -Iseconds)
        sed -i "s|<TIMESTAMP>|$TIMESTAMP|g" "$PROGRESS_FILE"
        echo -e "${GREEN}✓ 进度文件已初始化${NC}"
    fi
}

# 标记任务开始
start_task() {
    local task_id="$1"
    local task_name="$2"
    local timestamp=$(date -Iseconds)
    
    # 使用 Python 处理 JSON（更可靠）
    python3 << PYTHON_EOF
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        progress = json.load(f)
    
    if '$task_id' not in progress['tasks']:
        progress['tasks']['$task_id'] = {
            'name': '$task_name',
            'status': 'in_progress',
            'started_at': '$timestamp',
            'completed_at': None,
            'verified': False,
            'attempts': 0,
            'error': None
        }
        progress['last_updated'] = '$timestamp'
        
        with open('$PROGRESS_FILE', 'w') as f:
            json.dump(progress, f, indent=2)
        print("✓ 任务 $task_id 已开始")
    else:
        print("⚠ 任务 $task_id 已存在")
except Exception as e:
    print(f"✗ 错误: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# 标记任务完成（验证通过后）
complete_task() {
    local task_id="$1"
    local timestamp=$(date -Iseconds)
    
    python3 << PYTHON_EOF
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        progress = json.load(f)
    
    if '$task_id' in progress['tasks']:
        task = progress['tasks']['$task_id']
        
        # 只有验证通过的任务才能标记为完成
        if task.get('verified', False):
            task['status'] = 'completed'
            task['completed_at'] = '$timestamp'
            progress['completed_count'] = sum(1 for t in progress['tasks'].values() if t['status'] == 'completed')
            progress['last_updated'] = '$timestamp'
            
            with open('$PROGRESS_FILE', 'w') as f:
                json.dump(progress, f, indent=2)
            print(f"✓ 任务 {task['name']} 已完成")
        else:
            print("✗ 任务未验证，无法标记为完成", file=sys.stderr)
            sys.exit(1)
    else:
        print(f"✗ 任务 $task_id 不存在", file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f"✗ 错误: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# 标记任务验证通过
verify_task() {
    local task_id="$1"
    local verification_result="$2"  # true or false
    
    python3 << PYTHON_EOF
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        progress = json.load(f)
    
    if '$task_id' in progress['tasks']:
        progress['tasks']['$task_id']['verified'] = $verification_result
        progress['last_updated'] = '$(date -Iseconds)'
        
        with open('$PROGRESS_FILE', 'w') as f:
            json.dump(progress, f, indent=2)
        
        if $verification_result:
            print("✓ 任务验证通过")
        else:
            print("✗ 任务验证失败")
    else:
        print(f"✗ 任务 $task_id 不存在", file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f"✗ 错误: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# 记录任务失败
fail_task() {
    local task_id="$1"
    local error_message="$2"
    local timestamp=$(date -Iseconds)
    
    python3 << PYTHON_EOF
import json
import sys

try:
    with open('$PROGRESS_FILE', 'r') as f:
        progress = json.load(f)
    
    if '$task_id' in progress['tasks']:
        task = progress['tasks']['$task_id']
        task['status'] = 'failed'
        task['error'] = '''$error_message'''
        task['attempts'] = task.get('attempts', 0) + 1
        progress['last_updated'] = '$timestamp'
        
        with open('$PROGRESS_FILE', 'w') as f:
            json.dump(progress, f, indent=2)
        print(f"✗ 任务失败: $error_message")
    else:
        print(f"✗ 任务 $task_id 不存在", file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f"✗ 错误: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
}

# 增加重试次数
increment_retry() {
    local task_id="$1"
    
    python3 << PYTHON_EOF
import json

with open('$PROGRESS_FILE', 'r') as f:
    progress = json.load(f)

if '$task_id' in progress['tasks']:
    progress['tasks']['$task_id']['attempts'] = progress['tasks']['$task_id'].get('attempts', 0) + 1
    
    with open('$PROGRESS_FILE', 'w') as f:
        json.dump(progress, f, indent=2)
    
    attempts = progress['tasks']['$task_id']['attempts']
    print(f"重试次数: {attempts}")
PYTHON_EOF
}

# 检查任务是否完成
is_task_completed() {
    local task_id="$1"
    
    python3 << PYTHON_EOF
import json
import sys

with open('$PROGRESS_FILE', 'r') as f:
    progress = json.load(f)

if '$task_id' in progress['tasks']:
    status = progress['tasks']['$task_id']['status']
    if status == 'completed':
        print("true")
        sys.exit(0)
    else:
        print("false")
        sys.exit(1)
else:
    print("false")
    sys.exit(1)
PYTHON_EOF
}

# 获取任务状态
get_task_status() {
    local task_id="$1"
    
    python3 << PYTHON_EOF
import json

with open('$PROGRESS_FILE', 'r') as f:
    progress = json.load(f)

if '$task_id' in progress['tasks']:
    task = progress['tasks']['$task_id']
    print(f"状态: {task['status']}")
    print(f"验证: {'通过' if task['verified'] else '未通过'}")
    print(f"尝试: {task.get('attempts', 0)}")
    if task.get('error'):
        print(f"错误: {task['error']}")
else:
    print("任务不存在")
PYTHON_EOF
}

# 显示总体进度
show_progress() {
    python3 << PYTHON_EOF
import json
from datetime import datetime

with open('$PROGRESS_FILE', 'r') as f:
    progress = json.load(f)

print("=" * 60)
print("Repo Scout 任务进度")
print("=" * 60)
print(f"开始时间: {progress['initialized_at']}")
print(f"最后更新: {progress['last_updated']}")
print(f"完成进度: {progress['completed_count']}/{progress['total_count']}")
print()

# 任务状态图标
status_icons = {
    'completed': '✅',
    'in_progress': '⏳',
    'failed': '❌',
    'pending': '⏸️'
}

for task_id, task in progress['tasks'].items():
    icon = status_icons.get(task['status'], '❓')
    verified = '✓' if task.get('verified', False) else '✗'
    print(f"{icon} [{task_id}] {task['name']}")
    print(f"   状态: {task['status']} | 验证: {verified}")
    if task.get('error'):
        print(f"   错误: {task['error']}")
    print()

print("=" * 60)
PYTHON_EOF
}

# 主函数
main() {
    local command="$1"
    shift
    
    case "$command" in
        "init")
            init_progress
            ;;
        "start")
            start_task "$@"
            ;;
        "complete")
            complete_task "$@"
            ;;
        "verify")
            verify_task "$@"
            ;;
        "fail")
            fail_task "$@"
            ;;
        "retry")
            increment_retry "$@"
            ;;
        "is-completed")
            is_task_completed "$@"
            ;;
        "status")
            get_task_status "$@"
            ;;
        "show")
            show_progress
            ;;
        *)
            echo "用法: $0 {init|start|complete|verify|fail|retry|is-completed|status|show}"
            echo ""
            echo "命令:"
            echo "  init              初始化进度文件"
            echo "  start <id> <name> 标记任务开始"
            echo "  verify <id> <bool> 标记任务验证通过/失败"
            echo "  complete <id>     标记任务完成"
            echo "  fail <id> <error> 标记任务失败"
            echo "  retry <id>        增加重试次数"
            echo "  is-completed <id> 检查任务是否完成"
            echo "  status <id>       获取任务状态"
            echo "  show              显示总体进度"
            exit 1
            ;;
    esac
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
