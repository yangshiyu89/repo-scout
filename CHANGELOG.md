# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned Features
- Web UI interface
- Model performance benchmarking
- Containerized deployment options
- More model repository integrations
- AI-powered task planning
- Distributed execution support

## [2.0.0] - 2026-02-26

### Added - Major Features

#### Task Management System
- **Granular Task Tracking** - 细粒度任务跟踪系统
  - Task template with 14+ predefined tasks
  - Each task has unique ID, dependencies, and verification criteria
  - Tasks can be dynamically updated during execution
  - Support for parallel and sequential execution groups

#### Progress Tracking System
- **Progress Manager** - 进度管理器
  - Real-time progress tracking for each task
  - Binary state tracking: completed or not completed
  - Task verification before marking as complete
  - Automatic state persistence
  - Resume from interruption without starting over

#### Self-Verification Mechanism
- **Task Validator** - 任务验证器
  - 7 types of verification methods:
    - directory_exists
    - file_exists
    - command_exists
    - command_success
    - model_files_exist
    - directory_not_empty
    - output_files_exist
  - Tasks must pass verification before completion
  - Automatic verification before state updates

#### Download Retry Mechanism
- **Smart Retry System** - 智能重试系统
  - Automatic retry on network failures
  - Configurable retry count (default: 10 attempts)
  - Exponential backoff with configurable parameters
  - Resume interrupted downloads
  - Automatic failure handling actions:
    - Network connectivity check
    - Temporary file cleanup
    - Disk space verification
    - Connection throttling adjustment

#### Parallel Execution Enhancement
- **Improved Parallelism** - 增强并行执行
  - Parallel environment setup and model download
  - Task dependency graph for optimal execution order
  - Concurrent task groups with intelligent scheduling
  - Resource-aware parallelization

### Added - New Scripts

#### Task Manager Scripts
- `scripts/task_manager/progress_manager.sh` - Progress tracking and management
- `scripts/task_manager/task_validator.sh` - Task verification system
- `scripts/task_manager/download_retry.sh` - Download retry with exponential backoff
- `scripts/parallel_demo.sh` - Complete parallel execution example

#### Templates
- `templates/tasks_template.json` - Comprehensive task definition template
  - 14 predefined tasks covering full workflow
  - Dependency specifications
  - Verification criteria
  - Retry configurations
  - Time estimates

### Improved

#### Documentation
- **ARCHITECTURE.md** - Detailed architecture documentation
  - Skill working principles
  - Parallel execution mechanisms
  - Task management system explanation
  - Performance optimization strategies
- **SKILL_v2.md** - Enhanced skill documentation
  - Parallel execution workflows
  - tmux background execution
  - Task management integration
  - Complete examples

#### Reliability
- State persistence across interruptions
- Automatic cleanup on exit
- Better error handling and recovery
- Comprehensive logging system

### Technical Details

#### Task Management
```json
{
  "task_id": "task_007",
  "name": "Download Model",
  "verification": {
    "type": "model_files_exist",
    "min_files_required": 1
  },
  "retry": {
    "max_attempts": 10,
    "exponential_backoff": true
  }
}
```

#### Progress Tracking
```json
{
  "tasks": {
    "task_001": {
      "status": "completed",
      "verified": true,
      "attempts": 1
    }
  }
}
```

#### Download Retry
```bash
# Automatic retry with exponential backoff
download_with_retry "hfd.sh model-name" "model-name" "{
  \"max_retries\": 10,
  \"retry_delay\": 30,
  \"backoff_multiplier\": 2
}"
```

### Breaking Changes
- Minimum Python version: 3.8+ (was 3.8+)
- Requires jq for JSON processing
- Task structure changed (see migration guide)

### Migration Guide
If upgrading from v1.0.0:

1. Update task structure to new format
2. Run `bash scripts/task_manager/init_task_manager.sh` to initialize new system
3. Use `progress_manager.sh` instead of manual status tracking
4. Update custom scripts to use new verification system

### Known Issues
- Limited to repositories with existing inference scripts
- Some models may require manual configuration
- Large model downloads may timeout on slow connections (mitigated by retry system)

## [1.0.0] - 2026-02-26

### Added
- Initial release of Repo Scout
- Automated AI model repository research and deployment
- Support for ModelScope and HuggingFace model downloads
- Intelligent environment setup using uv
- Automatic inference script discovery and execution
- hfd.sh script for accelerated HuggingFace downloads
- Comprehensive documentation and examples
- MIT License
- Full test suite
- Contribution guidelines

### Features
- 🔧 Smart environment setup with uv package manager
- 📦 Multi-source model download (ModelScope优先，国内友好)
- 🚀 One-click inference execution
- 📋 Complete command recording
- 🌍 Cross-platform compatibility
- 🎯 Automatic demo data preparation
- 🔍 Automatic GPU detection and configuration
- 📁 Organized output management (.demo_output/)

### Documentation
- Comprehensive README with quick start guide
- Detailed skill documentation (SKILL.md)
- Contribution guidelines (CONTRIBUTING.md)
- Evaluation test cases
- Troubleshooting guide

### Supported Model Types
- Computer Vision models
- Natural Language Processing models
- Audio/Speech models
- Multimodal models
- Custom AI models with inference scripts

### Technical Requirements
- Python 3.8+
- uv package manager
- aria2c (for accelerated downloads)
- Git and Git LFS
- CUDA (optional, for GPU acceleration)

---

## Version History Summary

- **v2.0.0** (2026-02-26) - Task management, progress tracking, download retry, verification system
- **v1.0.0** (2026-02-26) - Initial release with core functionality
