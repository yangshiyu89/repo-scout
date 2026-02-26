#!/bin/bash
# Repo Scout - 智能恢复管理器
# 从中断点恢复任务执行，跳过已完成的任务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
REPO_PATH="${1:-.}"
TASKS_FILE="$REPO_PATH/.task_manager/tasks.json"
PROGRESS_FILE="$REPO_PATH/.task_manager/progress.json"

# 检查文件是否存在
check_files() {
    if [ ! -f "$TASKS_FILE" ]; then
        echo -e "${RED}错误: 任务文件不存在: $TASKS_FILE${NC}"
        echo -e "${YELLOW}请先运行初始化脚本${NC}"
        exit 1
    fi
    
    if [ ! -f "$PROGRESS_FILE" ]; then
        echo -e "${YELLOW}进度文件不存在，将从头开始执行${NC}"
        init_progress_file
    fi
}

# 初始化进度文件
init_progress_file() {
    python3 << PYTHON_EOF
import json
from datetime import datetime

progress = {
    "initialized_at": datetime.now().isoformat(),
    "last_updated": datetime.now().isoformat(),
    "overall_status": "in_progress",
    "completed_count": 0,
    "total_count": 0,
    "tasks": {}
}

with open('$PROGRESS_FILE', 'w') as f:
    json.dump(progress, f, indent=2)

print("✓ 进度文件已初始化")
PYTHON_EOF
}

# 分析任务依赖关系
analyze_task_dependencies() {
    python3 << PYTHON_EOF
import json

# 读取任务定义
with open('$TASKS_FILE', 'r') as f:
    tasks_data = json.load(f)

# 读取进度
try:
    with open('$PROGRESS_FILE', 'r') as f:
        progress = json.load(f)
except:
    progress = {"tasks": {}}

# 构建依赖图
dependency_graph = {}
task_info = {}

for task in tasks_data['tasks']:
    task_id = task['id']
    deps = task.get('dependencies', [])
    dependency_graph[task_id] = deps
    task_info[task_id] = {
        'name': task['name'],
        'category': task['category'],
        'priority': task.get('priority', 'medium'),
        'completed': progress['tasks'].get(task_id, {}).get('status') == 'completed'
    }

# 找出可以执行的任务（所有依赖都已完成）
ready_tasks = []
for task_id, deps in dependency_graph.items():
    if task_info[task_id]['completed']:
        continue  # 跳过已完成的任务
    
    # 检查所有依赖是否都已完成
    all_deps_completed = all(
        task_info[dep_id]['completed'] 
        for dep_id in deps
    )
    
    if all_deps_completed:
        ready_tasks.append(task_id)

# 按优先级排序
priority_order = {'high': 0, 'medium': 1, 'low': 2}
ready_tasks.sort(key=lambda t: priority_order.get(task_info[t]['priority'], 1))

# 输出结果
print("=" * 60)
print("任务依赖分析")
print("=" * 60)
print()

# 已完成的任务
completed = [tid for tid, info in task_info.items() if info['completed']]
print(f"✅ 已完成的任务 ({len(completed)}):")
for tid in completed:
    print(f"   - {tid}: {task_info[tid]['name']}")
print()

# 待执行的任务
pending = [tid for tid, info in task_info.items() if not info['completed']]
print(f"⏸️  待执行的任务 ({len(pending)}):")
for tid in pending:
    deps_status = "✓" if all(task_info[d]['completed'] for d in dependency_graph[tid]) else "✗"
    print(f"   - {tid}: {task_info[tid]['name']} (依赖: {deps_status})")
print()

# 可以立即执行的任务
if ready_tasks:
    print(f"🚀 可以立即执行的任务 ({len(ready_tasks)}):")
    for tid in ready_tasks:
        print(f"   - {tid}: {task_info[tid]['name']}")
else:
    print("⚠️  没有可以立即执行的任务（可能所有任务都已完成，或依赖未满足）")

print()
print("=" * 60)
print(f"总进度: {len(completed)}/{len(task_info)} ({len(completed)*100//len(task_info)}%)")
print("=" * 60)

# 保存待执行任务列表
with open('$REPO_PATH/.task_manager/ready_tasks.json', 'w') as f:
    json.dump({
        'ready_tasks': ready_tasks,
        'completed_tasks': completed,
        'pending_tasks': pending
    }, f, indent=2)

PYTHON_EOF
}

# 恢复执行
resume_execution() {
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Repo Scout 智能恢复                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    check_files
    
    # 分析依赖关系
    analyze_task_dependencies
    
    # 读取待执行任务
    READY_TASKS_FILE="$REPO_PATH/.task_manager/ready_tasks.json"
    
    if [ ! -f "$READY_TASKS_FILE" ]; then
        echo -e "${RED}错误: 无法生成任务分析${NC}"
        exit 1
    fi
    
    # 获取可执行任务
    READY_TASKS=$(python3 -c "import json; data=json.load(open('$READY_TASKS_FILE')); print(' '.join(data['ready_tasks']))")
    
    if [ -z "$READY_TASKS" ]; then
        echo ""
        echo -e "${GREEN}✅ 所有任务已完成！${NC}"
        echo -e "${BLUE}无需恢复执行${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}准备恢复执行以下任务:${NC}"
    for task_id in $READY_TASKS; do
        echo "  - $task_id"
    done
    echo ""
    
    # 询问用户确认
    echo -e "${YELLOW}是否继续执行？ [Y/n]${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
        echo -e "${BLUE}已取消恢复${NC}"
        return 0
    fi
    
    # 执行任务
    echo ""
    echo -e "${CYAN}开始执行任务...${NC}"
    echo ""
    
    for task_id in $READY_TASKS; do
        execute_single_task "$task_id"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ 任务 $task_id 执行失败${NC}"
            echo -e "${YELLOW}停止后续任务执行${NC}"
            return 1
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ 所有任务执行完成！${NC}"
}

# 执行单个任务
execute_single_task() {
    local task_id="$1"
    
    echo -e "${BLUE}═════════════════════════════════════════${NC}"
    echo -e "${BLUE}执行任务: $task_id${NC}"
    echo -e "${BLUE}═════════════════════════════════════════${NC}"
    
    # 获取任务信息
    TASK_INFO=$(python3 << PYTHON_EOF
import json
with open('$TASKS_FILE', 'r') as f:
    tasks = json.load(f)
for task in tasks['tasks']:
    if task['id'] == '$task_id':
        print(json.dumps(task))
        break
PYTHON_EOF
)
    
    if [ -z "$TASK_INFO" ]; then
        echo -e "${RED}✗ 任务不存在: $task_id${NC}"
        return 1
    fi
    
    # 提取任务信息
    TASK_NAME=$(echo "$TASK_INFO" | jq -r '.name')
    TASK_COMMAND=$(echo "$TASK_INFO" | jq -r '.command // empty')
    
    echo "任务名称: $TASK_NAME"
    echo ""
    
    # 标记任务开始
    bash scripts/task_manager/progress_manager.sh start "$task_id" "$TASK_NAME"
    
    # 如果有命令，执行命令
    if [ -n "$TASK_COMMAND" ] && [ "$TASK_COMMAND" != "null" ]; then
        echo "执行命令: $TASK_COMMAND"
        echo ""
        
        # 替换变量
        TASK_COMMAND=$(echo "$TASK_COMMAND" | sed "s|<REPO_PATH>|$REPO_PATH|g")
        
        # 执行
        cd "$REPO_PATH"
        eval "$TASK_COMMAND"
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            # 标记失败
            bash scripts/task_manager/progress_manager.sh fail "$task_id" "命令执行失败 (exit code: $exit_code)"
            return 1
        fi
    fi
    
    # 验证任务
    echo ""
    echo -e "${YELLOW}验证任务完成情况...${NC}"
    
    VERIFICATION_TYPE=$(echo "$TASK_INFO" | jq -r '.verification.type // empty')
    
    if [ -n "$VERIFICATION_TYPE" ]; then
        VERIFICATION_TARGET=$(echo "$TASK_INFO" | jq -r '.verification.target // empty')
        VERIFICATION_TARGET=$(echo "$VERIFICATION_TARGET" | sed "s|<REPO_PATH>|$REPO_PATH|g")
        
        bash scripts/task_manager/task_validator.sh run "$task_id" "$VERIFICATION_TYPE" "$VERIFICATION_TARGET"
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ 验证失败${NC}"
            bash scripts/task_manager/progress_manager.sh fail "$task_id" "验证失败"
            return 1
        fi
    else
        # 没有验证要求，直接标记为已验证
        bash scripts/task_manager/progress_manager.sh verify "$task_id" "true"
    fi
    
    # 标记任务完成
    bash scripts/task_manager/progress_manager.sh complete "$task_id"
    
    echo ""
    echo -e "${GREEN}✓ 任务完成: $TASK_NAME${NC}"
    echo ""
    
    return 0
}

# 显示恢复建议
show_resume_suggestions() {
    check_files
    
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     恢复建议                          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    
    python3 << PYTHON_EOF
import json

# 读取进度
with open('$PROGRESS_FILE', 'r') as f:
    progress = json.load(f)

# 读取任务
with open('$TASKS_FILE', 'r') as f:
    tasks = json.load(f)

print("当前状态:")
print(f"  总任务数: {len(tasks['tasks'])}")
print(f"  已完成: {progress['completed_count']}")
print()

# 找出失败或进行中的任务
problematic = []
for task_id, task_progress in progress['tasks'].items():
    if task_progress['status'] in ['failed', 'in_progress']:
        problematic.append({
            'id': task_id,
            'name': task_progress['name'],
            'status': task_progress['status'],
            'attempts': task_progress.get('attempts', 0)
        })

if problematic:
    print("⚠️  需要关注的问题任务:")
    for task in problematic:
        print(f"  - {task['id']}: {task['name']}")
        print(f"    状态: {task['status']}, 尝试次数: {task['attempts']}")
    print()
    
    print("建议操作:")
    print("1. 检查问题任务的日志")
    print("2. 手动修复问题")
    print("3. 使用 'resume' 命令重新执行")
else:
    print("✅ 所有已开始的任务都已完成")

PYTHON_EOF
}

# 主函数
main() {
    local command="$1"
    shift
    
    case "$command" in
        "analyze")
            check_files
            analyze_task_dependencies
            ;;
        "resume")
            resume_execution
            ;;
        "suggestions")
            show_resume_suggestions
            ;;
        "status")
            check_files
            echo ""
            python3 << PYTHON_EOF
import json

with open('$PROGRESS_FILE', 'r') as f:
    progress = json.load(f)

print("=" * 60)
print("任务进度总览")
print("=" * 60)
print(f"开始时间: {progress['initialized_at']}")
print(f"最后更新: {progress['last_updated']}")
print(f"完成进度: {progress['completed_count']}/{progress['total_count']}")
print()

for task_id, task in progress['tasks'].items():
    status_icon = {'completed': '✅', 'in_progress': '⏳', 'failed': '❌'}.get(task['status'], '❓')
    print(f"{status_icon} {task_id}: {task['name']}")
    print(f"   状态: {task['status']}, 验证: {'✓' if task.get('verified') else '✗'}")

PYTHON_EOF
            ;;
        *)
            echo "用法: $0 {analyze|resume|suggestions|status} [repo_path]"
            echo ""
            echo "命令:"
            echo "  analyze     分析任务依赖关系，找出可执行的任务"
            echo "  resume      从中断点恢复执行"
            echo "  suggestions 显示恢复建议"
            echo "  status      显示当前进度状态"
            echo ""
            echo "示例:"
            echo "  $0 analyze /workspace/repo"
            echo "  $0 resume /workspace/repo"
            echo "  $0 suggestions /workspace/repo"
            echo "  $0 status /workspace/repo"
            exit 1
            ;;
    esac
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
