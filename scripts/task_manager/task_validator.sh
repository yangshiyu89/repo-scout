#!/bin/bash
# Repo Scout - 任务验证器

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 验证类型
# 1. directory_exists - 检查目录是否存在
# 2. file_exists - 检查文件是否存在
# 3. command_exists - 检查命令是否存在
# 4. command_success - 检查命令是否成功
# 5. model_files_exist - 检查模型文件是否存在
# 6. directory_not_empty - 检查目录不为空
# 7. output_files_exist - 检查输出文件存在

# 验证函数
verify_task() {
    local task_id="$1"
    local verification_type="$2"
    shift 2
    local verification_params=("$@")
    
    echo -e "${BLUE}[验证] 任务 $task_id - 类型: $verification_type${NC}"
    
    case "$verification_type" in
        "directory_exists")
            verify_directory_exists "${verification_params[@]}"
            ;;
        "file_exists")
            verify_file_exists "${verification_params[@]}"
            ;;
        "command_exists")
            verify_command_exists "${verification_params[@]}"
            ;;
        "command_success")
            verify_command_success "${verification_params[@]}"
            ;;
        "model_files_exist")
            verify_model_files_exist "${verification_params[@]}"
            ;;
        "directory_not_empty")
            verify_directory_not_empty "${verification_params[@]}"
            ;;
        "output_files_exist")
            verify_output_files_exist "${verification_params[@]}"
            ;;
        "custom")
            verify_custom "${verification_params[@]}"
            ;;
        *)
            echo -e "${RED}✗ 未知的验证类型: $verification_type${NC}"
            return 1
            ;;
    esac
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓ 验证通过${NC}"
        # 标记验证通过
        if [ -f ".task_manager/progress.json" ]; then
            bash scripts/task_manager/progress_manager.sh verify "$task_id" "true"
        fi
    else
        echo -e "${RED}✗ 验证失败${NC}"
        if [ -f ".task_manager/progress.json" ]; then
            bash scripts/task_manager/progress_manager.sh verify "$task_id" "false"
        fi
    fi
    
    return $result
}

# 验证目录存在
verify_directory_exists() {
    local dir_path="$1"
    
    echo "检查目录: $dir_path"
    
    if [ -d "$dir_path" ]; then
        echo -e "${GREEN}  ✓ 目录存在${NC}"
        
        # 检查附加条件
        if [ ${#verification_params[@]} -gt 1 ]; then
            for check in "${verification_params[@]:1}"; do
                echo "  执行检查: $check"
                if eval "$check"; then
                    echo -e "${GREEN}  ✓ 检查通过${NC}"
                else
                    echo -e "${RED}  ✗ 检查失败${NC}"
                    return 1
                fi
            done
        fi
        
        return 0
    else
        echo -e "${RED}  ✗ 目录不存在${NC}"
        return 1
    fi
}

# 验证文件存在
verify_file_exists() {
    local file_path="$1"
    
    echo "检查文件: $file_path"
    
    if [ -f "$file_path" ]; then
        local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
        echo -e "${GREEN}  ✓ 文件存在 (大小: $file_size bytes)${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 文件不存在${NC}"
        return 1
    fi
}

# 验证命令存在
verify_command_exists() {
    local command="$1"
    
    echo "检查命令: $command"
    
    if command -v "$command" &> /dev/null; then
        local cmd_path=$(command -v "$command")
        echo -e "${GREEN}  ✓ 命令存在: $cmd_path${NC}"
        return 0
    elif [ -f "$command" ] && [ -x "$command" ]; then
        echo -e "${GREEN}  ✓ 脚本存在且可执行: $command${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 命令不存在${NC}"
        return 1
    fi
}

# 验证命令成功
verify_command_success() {
    local check_command="$1"
    local expected_output="${2:-}"
    
    echo "执行验证命令: $check_command"
    
    local output
    output=$(eval "$check_command" 2>&1)
    local exit_code=$?
    
    echo "  输出: $output"
    echo "  退出码: $exit_code"
    
    if [ $exit_code -eq 0 ]; then
        if [ -n "$expected_output" ]; then
            if echo "$output" | grep -q "$expected_output"; then
                echo -e "${GREEN}  ✓ 命令成功且输出匹配${NC}"
                return 0
            else
                echo -e "${RED}  ✗ 命令成功但输出不匹配${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}  ✓ 命令成功${NC}"
            return 0
        fi
    else
        echo -e "${RED}  ✗ 命令失败${NC}"
        return 1
    fi
}

# 验证模型文件存在
verify_model_files_exist() {
    local model_dir="$1"
    shift
    local expected_files=("$@")
    local min_files="${1:-1}"
    
    echo "检查模型目录: $model_dir"
    
    if [ ! -d "$model_dir" ]; then
        echo -e "${RED}  ✗ 模型目录不存在${NC}"
        return 1
    fi
    
    local found_count=0
    local missing_files=()
    
    # 常见模型文件
    local common_model_files=(
        "config.json"
        "pytorch_model.bin"
        "model.safetensors"
        "pytorch_model.bin.index.json"
        "model.safetensors.index.json"
        "tokenizer.json"
        "tokenizer_config.json"
        "vocab.json"
        "merges.txt"
        "special_tokens_map.json"
    )
    
    # 如果没有指定文件，检查常见文件
    if [ ${#expected_files[@]} -eq 0 ]; then
        expected_files=("${common_model_files[@]}")
    fi
    
    echo "  检查模型文件..."
    for file in "${expected_files[@]}"; do
        local file_path="$model_dir/$file"
        if [ -f "$file_path" ]; then
            local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null)
            echo -e "${GREEN}    ✓ $file ($file_size bytes)${NC}"
            ((found_count++))
        else
            missing_files+=("$file")
        fi
    done
    
    echo ""
    echo "  找到 $found_count 个模型文件"
    
    if [ $found_count -ge $min_files ]; then
        echo -e "${GREEN}  ✓ 验证通过 (至少需要 $min_files 个文件)${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 验证失败 (需要至少 $min_files 个文件，只找到 $found_count 个)${NC}"
        if [ ${#missing_files[@]} -gt 0 ]; then
            echo "  缺失的文件:"
            printf '    - %s\n' "${missing_files[@]}"
        fi
        return 1
    fi
}

# 验证目录不为空
verify_directory_not_empty() {
    local dir_path="$1"
    local min_files="${2:-1}"
    
    echo "检查目录: $dir_path"
    
    if [ ! -d "$dir_path" ]; then
        echo -e "${RED}  ✗ 目录不存在${NC}"
        return 1
    fi
    
    local file_count=$(find "$dir_path" -type f | wc -l)
    local dir_count=$(find "$dir_path" -mindepth 1 -type d | wc -l)
    
    echo "  文件数: $file_count"
    echo "  子目录数: $dir_count"
    
    if [ $file_count -ge $min_files ]; then
        echo -e "${GREEN}  ✓ 目录不为空 (至少需要 $min_files 个文件)${NC}"
        
        # 显示文件列表
        if [ $file_count -le 10 ]; then
            echo "  文件列表:"
            find "$dir_path" -type f -exec ls -lh {} \; | awk '{print "    " $9 " (" $5 ")"}'
        fi
        
        return 0
    else
        echo -e "${RED}  ✗ 目录为空或文件数不足${NC}"
        return 1
    fi
}

# 验证输出文件存在
verify_output_files_exist() {
    local output_dir="$1"
    local min_files="${2:-1}"
    local max_age_hours="${3:-24}"  # 文件最大年龄（小时）
    
    echo "检查输出目录: $output_dir"
    
    if [ ! -d "$output_dir" ]; then
        echo -e "${RED}  ✗ 输出目录不存在${NC}"
        return 1
    fi
    
    # 查找最近生成的文件
    local recent_files=$(find "$output_dir" -type f -mmin -$((max_age_hours * 60)))
    local recent_count=$(echo "$recent_files" | grep -c .)
    
    echo "  最近 $max_age_hours 小时内的文件数: $recent_count"
    
    if [ $recent_count -ge $min_files ]; then
        echo -e "${GREEN}  ✓ 找到足够的输出文件${NC}"
        
        # 显示文件列表
        echo "  输出文件:"
        echo "$recent_files" | while read file; do
            if [ -n "$file" ]; then
                local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
                local mtime=$(stat -f "%Sm" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null)
                echo "    $file ($size bytes, 修改: $mtime)"
            fi
        done
        
        return 0
    else
        echo -e "${RED}  ✗ 输出文件数不足${NC}"
        return 1
    fi
}

# 自定义验证
verify_custom() {
    local validation_script="$1"
    shift
    local params=("$@")
    
    echo "执行自定义验证: $validation_script"
    
    if [ ! -f "$validation_script" ]; then
        echo -e "${RED}  ✗ 验证脚本不存在${NC}"
        return 1
    fi
    
    if [ ! -x "$validation_script" ]; then
        echo -e "${YELLOW}  ⚠ 脚本不可执行，尝试添加权限...${NC}"
        chmod +x "$validation_script"
    fi
    
    # 执行验证脚本
    if bash "$validation_script" "${params[@]}"; then
        echo -e "${GREEN}  ✓ 自定义验证通过${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 自定义验证失败${NC}"
        return 1
    fi
}

# 主函数
main() {
    local command="$1"
    shift
    
    case "$command" in
        "run")
            verify_task "$@"
            ;;
        "directory")
            verify_directory_exists "$@"
            ;;
        "file")
            verify_file_exists "$@"
            ;;
        "command")
            verify_command_exists "$@"
            ;;
        "model")
            verify_model_files_exist "$@"
            ;;
        "output")
            verify_output_files_exist "$@"
            ;;
        *)
            echo "用法: $0 {run|directory|file|command|model|output} [参数...]"
            echo ""
            echo "示例:"
            echo "  $0 run task_001 directory_exists /path/to/dir"
            echo "  $0 directory /path/to/dir"
            echo "  $0 file /path/to/file"
            echo "  $0 command python"
            echo "  $0 model /path/to/model config.json pytorch_model.bin"
            echo "  $0 output /path/to/output 1"
            exit 1
            ;;
    esac
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
