# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of Repo Scout
- Automated AI model repository research and deployment
- Support for ModelScope and HuggingFace model downloads
- Intelligent environment setup using uv
- Automatic inference script discovery and execution

### Features
- Fast AI model repository research and deployment
- Multi-source model download support (ModelScope, HuggingFace)
- Intelligent environment setup using uv instead of conda
- Automatic inference script discovery and execution
- Complete command logging for reproducibility
- Cross-platform support (Linux, macOS, Windows)

### Known Issues
- Limited to repositories with existing inference scripts
- Some models may require manual configuration

## [1.0.0] - 2024-02-26

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

- **v1.0.0** - Initial release with core functionality
- Future versions will include:
  - Web UI interface
  - Model performance benchmarking
  - Containerized deployment options
  - More model repository integrations