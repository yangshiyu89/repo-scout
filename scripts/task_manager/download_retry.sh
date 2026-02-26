#!/bin/bash
# Repo Scout - 下载重试管理器
# 支持自动重试、断点续传、轮询下载

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
DEFAULT_MAX_RETRIES=10
DEFAULT_RETRY_DELAY=30
DEFAULT_BACKOFF_MULTIPLIER=2
DEFAULT_MAX_DELAY=300

# 下载重试函数
download_with_retry() {
    local download_command="$1"
    local model_or_dataset="$2"
    local options="${3:-}"
    
    # 解析选项
    local max_retries=$(echo "$options" | jq -r '.max_retries // 10')
    local retry_delay=$(echo "$options" | jq -r '.retry_delay // 30')
    local backoff_multiplier=$(echo "$options" | jq -r '.backoff_multiplier // 2')
    local max_delay=$(echo "$options" | jq -r '.max_delay // 300')
    local resumable=$(echo "$options" | jq -r '.resumable // true')
    
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     下载重试管理器                     ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}目标:${NC} $model_or_dataset"
    echo -e "${BLUE}最大重试:${NC} $max_retries 次"
    echo -e "${BLUE}初始延迟:${NC} ${retry_delay}秒"
    echo -e "${BLUE}指数退避:${NC} ${backoff_multiplier}x"
    echo -e "${BLUE}最大延迟:${NC} ${max_delay}秒"
    echo -e "${BLUE}支持续传:${NC} $resumable"
    echo ""
    
    local attempt=0
    local current_delay=$retry_delay
    
    while [ $attempt -lt $max_retries ]; do
        attempt=$((attempt + 1))
        
        echo -e "${BLUE}═════════════════════════════════════════${NC}"
        echo -e "${YELLOW}尝试 $attempt/$max_retries${NC}"
        echo -e "${BLUE}═════════════════════════════════════════${NC}"
        echo ""
        
        # 记录开始时间
        local start_time=$(date +%s)
        
        # 执行下载命令
        echo -e "${CYAN}执行下载命令...${NC}"
        eval "$download_command"
        local exit_code=$?
        
        # 记录结束时间
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        echo ""
        echo "下载耗时: ${duration}秒"
        
        # 检查是否成功
        if [ $exit_code -eq 0 ]; then
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║     ✅ 下载成功                        ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
            echo ""
            echo "总尝试次数: $attempt"
            echo "总耗时: $(calculate_total_time $attempt $retry_delay $backoff_multiplier $duration)秒"
            return 0
        fi
        
        # 下载失败
        echo ""
        echo -e "${RED}✗ 下载失败 (退出码: $exit_code)${NC}"
        
        # 如果不是最后一次尝试
        if [ $attempt -lt $max_retries ]; then
            echo ""
            echo -e "${YELLOW}将在 ${current_delay}秒 后重试...${NC}"
            echo ""
            
            # 执行失败处理动作
            execute_failure_actions "$model_or_dataset" "$attempt"
            
            # 倒计时
            countdown $current_delay
            
            # 指数退避
            current_delay=$(calculate_backoff_delay $current_delay $backoff_multiplier $max_delay)
        fi
    done
    
    # 所有重试都失败
    echo ""
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║     ❌ 下载失败                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "已达到最大重试次数: $max_retries"
    echo ""
    echo -e "${YELLOW}建议操作:${NC}"
    echo "1. 检查网络连接"
    echo "2. 尝试使用 VPN"
    echo "3. 更换镜像源"
    echo "4. 检查磁盘空间"
    echo "5. 手动下载后放置到正确位置"
    echo ""
    
    # 保存失败状态
    save_failure_state "$model_or_dataset" "$attempt" "$exit_code"
    
    return 1
}

# 计算退避延迟
calculate_backoff_delay() {
    local current_delay=$1
    local multiplier=$2
    local max_delay=$3
    
    local new_delay=$((current_delay * multiplier))
    
    if [ $new_delay -gt $max_delay ]; then
        echo $max_delay
    else
        echo $new_delay
    fi
}

# 倒计时
countdown() {
    local seconds=$1
    
    while [ $seconds -gt 0 ]; do
        echo -ne "\r${CYAN}剩余等待时间: ${seconds}秒${NC}  "
        sleep 1
        seconds=$((seconds - 1))
    done
    echo -e "\r${GREEN}开始重试...              ${NC}"
}

# 计算总耗时
calculate_total_time() {
    local attempts=$1
    local initial_delay=$2
    local multiplier=$3
    local last_download_time=$4
    
    local total_wait=0
    local current_delay=$initial_delay
    
    # 计算所有等待时间的总和（除了最后一次下载）
    for ((i=1; i<attempts; i++)); do
        total_wait=$((total_wait + current_delay))
        current_delay=$(calculate_backoff_delay $current_delay $multiplier $DEFAULT_MAX_DELAY)
    done
    
    echo $total_wait
}

# 执行失败处理动作
execute_failure_actions() {
    local model_or_dataset="$1"
    local attempt="$2"
    
    echo -e "${BLUE}执行失败处理动作...${NC}"
    
    # 动作 1: 检查网络连接
    echo "1. 检查网络连接..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "   ${GREEN}✓ 网络正常${NC}"
    else
        echo -e "   ${RED}✗ 网络异常${NC}"
    fi
    
    # 动作 2: 清理部分下载的文件（可选）
    if [ $((attempt % 3)) -eq 0 ]; then
        echo "2. 清理临时文件..."
        find . -name "*.tmp" -o -name "*.part" -o -name "*.aria2" | head -5 | while read file; do
            echo "   清理: $file"
            rm -f "$file"
        done
    fi
    
    # 动作 3: 检查磁盘空间
    echo "3. 检查磁盘空间..."
    local available=$(df -h . | awk 'NR==2 {print $4}')
    echo "   可用空间: $available"
    
    # 动作 4: 调整并发数（针对 aria2c）
    if [ $attempt -ge 5 ]; then
        echo "4. 减少并发连接数..."
        export REDUCED_CONNECTIONS=true
    fi
}

# 保存失败状态
save_failure_state() {
    local model="$1"
    local attempts="$2"
    local exit_code="$3"
    
    local state_file=".task_manager/download_failures.json"
    
    mkdir -p .task_manager
    
    python3 << PYTHON_EOF
import json
import os
from datetime import datetime

state_file = "$state_file"
model = "$model"
attempts = $attempts
exit_code = $exit_code

# 读取现有状态
if os.path.exists(state_file):
    with open(state_file, 'r') as f:
        state = json.load(f)
else:
    state = {"failures": []}

# 添加新的失败记录
state["failures"].append({
    "model": model,
    "attempts": attempts,
    "exit_code": exit_code,
    "timestamp": datetime.now().isoformat()
})

# 保存
with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)

print(f"失败状态已保存到 {state_file}")
PYTHON_EOF
}

# HuggingFace 下载（带重试）
download_huggingface_with_retry() {
    local model_name="$1"
    local options="${2:-}"
    
    # 默认选项
    local max_retries=$(echo "$options" | jq -r '.max_retries // 10')
    local hf_username=$(echo "$options" | jq -r '.hf_username // ""')
    local hf_token=$(echo "$options" | jq -r '.hf_token // ""')
    local tool=$(echo "$options" | jq -r '.tool // "aria2c"')
    local threads=$(echo "$options" | jq -r '.threads // 10')
    
    # 构建下载命令
    local cmd="$HOME/.local/bin/hfd.sh $model_name --tool $tool -x $threads"
    
    if [ -n "$hf_username" ] && [ -n "$hf_token" ]; then
        cmd="$cmd --hf_username $hf_username --hf_token $hf_token"
    fi
    
    # 执行下载
    download_with_retry "$cmd" "$model_name" "{
        \"max_retries\": $max_retries,
        \"retry_delay\": 30,
        \"backoff_multiplier\": 2,
        \"max_delay\": 300,
        \"resumable\": true
    }"
}

# ModelScope 下载（带重试）
download_modelscope_with_retry() {
    local model_name="$1"
    local options="${2:-}"
    
    local max_retries=$(echo "$options" | jq -r '.max_retries // 10')
    
    # Python 下载脚本
    local python_script=$(cat << 'PYTHON_EOF'
import sys
import os
from modelscope import snapshot_download

try:
    model_dir = snapshot_download(
        sys.argv[1],
        cache_dir=os.environ.get('MODELSCOPE_CACHE', None)
    )
    print(f"模型已下载到: {model_dir}")
    sys.exit(0)
except Exception as e:
    print(f"下载失败: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF
)
    
    local cmd="pip install modelscope && python -c \"$python_script\" $model_name"
    
    download_with_retry "$cmd" "$model_name" "{
        \"max_retries\": $max_retries,
        \"retry_delay\": 30,
        \"backoff_multiplier\": 2,
        \"max_delay\": 300,
        \"resumable\": false
    }"
}

# 智能下载（自动选择源）
smart_download_with_retry() {
    local model_name="$1"
    local options="${2:-}"
    
    local prefer_modelscope=$(echo "$options" | jq -r '.prefer_modelscope // true')
    local check_modelscope_first=$(echo "$options" | jq -r '.check_modelscope_first // true')
    
    echo -e "${CYAN}智能下载模式${NC}"
    echo ""
    
    # 优先使用 ModelScope（国内）
    if [ "$prefer_modelscope" = "true" ]; then
        echo "尝试从 ModelScope 下载..."
        if download_modelscope_with_retry "$model_name" "$options"; then
            return 0
        fi
        echo ""
        echo "ModelScope 下载失败，切换到 HuggingFace..."
    fi
    
    # 使用 HuggingFace
    echo "尝试从 HuggingFace 下载..."
    if download_huggingface_with_retry "$model_name" "$options"; then
        return 0
    fi
    
    return 1
}

# 主函数
main() {
    local command="$1"
    shift
    
    case "$command" in
        "hf")
            download_huggingface_with_retry "$@"
            ;;
        "modelscope")
            download_modelscope_with_retry "$@"
            ;;
        "smart")
            smart_download_with_retry "$@"
            ;;
        "custom")
            local download_cmd="$1"
            local name="$2"
            local options="${3:-{\} }"
            download_with_retry "$download_cmd" "$name" "$options"
            ;;
        *)
            echo "用法: $0 {hf|modelscope|smart|custom} [参数...]"
            echo ""
            echo "命令:"
            echo "  hf <model> [options_json]         从 HuggingFace 下载（带重试）"
            echo "  modelscope <model> [options_json] 从 ModelScope 下载（带重试）"
            echo "  smart <model> [options_json]      智能选择源下载（带重试）"
            echo "  custom <cmd> <name> [options]     自定义命令下载（带重试）"
            echo ""
            echo "选项 (JSON格式):"
            echo "  {"
            echo "    \"max_retries\": 10,"
            echo "    \"retry_delay\": 30,"
            echo "    \"backoff_multiplier\": 2,"
            echo "    \"max_delay\": 300,"
            echo "    \"hf_username\": \"your_username\","
            echo "    \"hf_token\": \"your_token\","
            echo "    \"prefer_modelscope\": true"
            echo "  }"
            echo ""
            echo "示例:"
            echo "  $0 hf bigscience/bloom-560m"
            echo "  $0 modelscope damo/nlp_structbert_sentence-similarity_chinese-base"
            echo "  $0 smart user/model '{\"max_retries\": 5}'"
            exit 1
            ;;
    esac
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
