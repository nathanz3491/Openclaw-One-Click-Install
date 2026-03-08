# Contributing to OpenClaw Installer

Thank you for your interest in contributing to the OpenClaw Universal Installer! This document provides guidelines and instructions for contributing.

## 🎯 How to Contribute

### Reporting Bugs

If you find a bug, please open an issue with the following information:

- **OS and version** (e.g., macOS 14.2, Ubuntu 22.04, Windows 11)
- **Shell** (e.g., bash, zsh, PowerShell 7)
- **What you were trying to do**
- **What actually happened**
- **Error messages or logs** (use `--verbose` flag)

### Suggesting Enhancements

We welcome feature suggestions! Please open an issue describing:

- The use case
- The proposed solution
- Any alternatives you've considered

### Pull Requests

1. Fork the repository
2. Create a new branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test on multiple platforms if possible
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 🧪 Testing

### Testing Locally

**Bash Script:**
```bash
# Make executable
chmod +x install.sh

# Test with dry-run
./install.sh --dry-run

# Test with verbose output
./install.sh --verbose --dry-run

# Test CI mode
./install.sh --no-prompt --no-onboard --dry-run
```

**PowerShell Script:**
```powershell
# Test with dry-run
.\install.ps1 -DryRun

# Test with verbose output
.\install.ps1 -Verbose -DryRun

# Test CI mode
.\install.ps1 -NoPrompt -NoOnboard -DryRun
```

### Testing in Docker

```bash
# Test on Ubuntu
docker run --rm -it -v "$PWD:/installer" ubuntu:22.04 bash -c "
  apt-get update && apt-get install -y curl
  /installer/install.sh --dry-run
"

# Test on Alpine
docker run --rm -it -v "$PWD:/installer" alpine:latest sh -c "
  apk add curl bash
  /installer/install.sh --dry-run
"
```

## 📝 Code Style

### Bash

- Use `#!/bin/bash` with `set -euo pipefail`
- Quote all variables: `"$variable"`
- Use `[[ ]]` for tests, not `[ ]`
- Prefer `local` variables in functions
- Use meaningful function names with `snake_case`
- Add comments for complex logic

Example:
```bash
# Good
my_function() {
    local input="$1"
    if [[ -n "$input" ]]; then
        echo "$input"
    fi
}

# Bad
myfunction() {
    input=$1
    if [ ! -z $input ]; then echo $input; fi
}
```

### PowerShell

- Use `CmdletBinding()` for advanced functions
- Use `param()` block for parameters
- Use `Verb-Noun` naming convention
- Use `$script:` prefix for script-level variables
- Add comment-based help for functions

Example:
```powershell
function Test-NodeVersion {
    [CmdletBinding()]
    param()
    
    try {
        $version = node --version 2>$null
        return ($version -replace '^v', '')
    }
    catch {
        return $null
    }
}
```

## 🏗️ Project Structure

```
openclaw-installer/
├── install.sh           # Bash installer
├── install.ps1          # PowerShell installer
├── LICENSE              # MIT License
├── README.md            # Main documentation
└── CONTRIBUTING.md      # This file
```

## 🎨 Design Principles

1. **Simplicity**: Keep the installer simple and easy to understand
2. **Robustness**: Handle errors gracefully and provide helpful messages
3. **Portability**: Work across different shells and platforms
4. **Security**: Use HTTPS, verify checksums, don't expose secrets
5. **User Experience**: Provide clear feedback and beautiful UI when possible

## 🐚 Shell Compatibility

The bash script should work with:
- bash 3.2+ (macOS default)
- bash 4.x+ (Linux)
- zsh (when running as script)

Avoid:
- bash 4+ specific features
- Process substitution `<()` when possible
- Associative arrays
- `declare -A`

## 🧹 Before Submitting

- [ ] Test on your local machine
- [ ] Test with `--dry-run` flag
- [ ] Test with `--verbose` flag
- [ ] Check for shellcheck warnings: `shellcheck install.sh`
- [ ] Update README.md if adding new features
- [ ] Update this file if changing contribution process

## 📞 Getting Help

- Open an issue for questions
- Join the [OpenClaw Discord](https://discord.gg/openclaw)
- Check existing issues and PRs first

## 🙏 Recognition

Contributors will be recognized in our README.md file.

Thank you for contributing! 🦞
