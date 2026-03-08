# OpenClaw Universal Installer

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/yourusername/openclaw-installer)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-12%2B-blueviolet.svg)](https://www.apple.com/macos)
[![Linux](https://img.shields.io/badge/Linux-supported-success.svg)](https://kernel.org)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-blue.svg)](https://www.microsoft.com/windows)

A robust, cross-platform installation script for [OpenClaw](https://openclaw.ai) - your personal AI assistant that works with WhatsApp, Telegram, Discord, Slack, and more.

## ✨ Features

- 🖥️ **Cross-Platform**: Works on Windows, macOS, Linux, and WSL
- 🛠️ **All-Circumstance**: Handles missing dependencies, build tools, and various system configurations
- 📦 **Multiple Install Methods**: npm (recommended) or git clone
- 🤖 **Interactive & CI/CD Friendly**: Works in interactive shells and automation pipelines
- 🔧 **Self-Healing**: Automatically installs missing prerequisites (Node.js, build tools)
- 🎨 **Beautiful UI**: Uses [gum](https://github.com/charmbracelet/gum) for enhanced terminal UI when available

## 🚀 Quick Install

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash
```

Or with `wget`:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.ps1 | iex
```

## 📋 Installation Options

### Install Specific Version

**Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash -s -- --version 1.2.3
```

**PowerShell:**
```powershell
iwr -useb https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.ps1 | iex -Args "-Version 1.2.3"
```

### Install Beta Version

**Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash -s -- --beta
```

**PowerShell:**
```powershell
iwr -useb https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.ps1 | iex -Args "-Beta"
```

### Install from Git (Development)

**Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash -s -- --install-method git
```

**PowerShell:**
```powershell
iwr -useb https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.ps1 | iex -Args "-InstallMethod git"
```

### CI/CD Non-Interactive Mode

**Bash:**
```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.sh | bash -s -- --no-prompt --no-onboard
```

**PowerShell:**
```powershell
iwr -useb https://raw.githubusercontent.com/yourusername/openclaw-installer/main/install.ps1 | iex -Args "-NoPrompt -NoOnboard"
```

## 🔧 Environment Variables

All options can also be set via environment variables:

| Variable | Description |
|----------|-------------|
| `OPENCLAW_INSTALL_METHOD` | Installation method: `npm` or `git` |
| `OPENCLAW_VERSION` | Version to install (e.g., `1.2.3`, `latest`, `beta`) |
| `OPENCLAW_BETA=1` | Use beta channel |
| `OPENCLAW_GIT_DIR` | Directory for git clone (default: `~/openclaw`) |
| `OPENCLAW_GIT_UPDATE=0` | Skip git pull for existing checkout |
| `OPENCLAW_NO_ONBOARD=1` | Skip onboarding wizard |
| `OPENCLAW_NO_PROMPT=1` | Non-interactive mode |
| `OPENCLAW_DRY_RUN=1` | Show what would be done without making changes |
| `OPENCLAW_VERBOSE=1` | Enable verbose output |

## 📦 Prerequisites Handling

The installer automatically handles missing prerequisites:

### Node.js 22+

- **macOS**: Uses Homebrew or installs from nodejs.org
- **Linux**: Uses package manager (apt, dnf, yum, pacman, apk) or NodeSource repositories
- **Windows**: Uses winget, Chocolatey, Scoop, or direct MSI installer

### Build Tools (for native npm modules)

- **macOS**: Xcode Command Line Tools
- **Linux**: build-essential, python3, make, g++, cmake
- **Windows**: Visual Studio Build Tools

## 💻 Platform-Specific Notes

### macOS

- Requires macOS 12 (Monterey) or later
- Homebrew is used when available
- Administrator privileges may be required for some installations

### Linux

Supported distributions:
- ✅ Ubuntu 20.04+
- ✅ Debian 11+
- ✅ Fedora 35+
- ✅ CentOS/RHEL 8+
- ✅ Arch Linux
- ✅ Alpine Linux
- ✅ openSUSE
- ✅ And more...

### Windows

- Requires Windows 10 version 1809+ or Windows 11
- PowerShell 5.1 or PowerShell 7+ recommended
- Windows Terminal provides the best experience
- May require Administrator privileges for some installations

### WSL (Windows Subsystem for Linux)

- WSL2 recommended for best performance
- Treated as Linux with Windows integration features
- Same requirements as the host Linux distribution

## 🐛 Troubleshooting

### Permission Errors (npm)

If you see permission errors during npm install:

```bash
# Option 1: Fix npm permissions (recommended)
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Option 2: Use a Node version manager
# nvm: https://github.com/nvm-sh/nvm
# fnm: https://github.com/Schniz/fnm
```

### Missing Build Tools

**macOS:**
```bash
xcode-select --install
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y build-essential python3 make g++ cmake
```

**Fedora/RHEL:**
```bash
sudo dnf install -y gcc gcc-c++ make cmake python3
```

**Windows:**
```powershell
# Via Chocolatey
choco install visualstudio2022buildtools

# Via winget
winget install Microsoft.VisualStudio.2022.BuildTools
```

### PATH Issues

If `openclaw` command is not found after installation:

**Bash/Zsh:**
```bash
# Add to ~/.bashrc or ~/.zshrc
export PATH="$(npm config get prefix)/bin:$PATH"
```

**PowerShell:**
```powershell
# Add to $PROFILE
[Environment]::SetEnvironmentVariable('Path', 
    [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + (npm config get prefix) + '\bin',
    'User')
```

## 📝 Manual Installation

If the automatic installer doesn't work for your use case:

### Via npm (Recommended)

```bash
# Requires Node.js 22+
npm install -g openclaw
```

### From Source

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install  # or npm install
pnpm build    # or npm run build
pnpm link --global  # or npm link
```

## 📁 Repository Structure

```
openclaw-installer/
├── install.sh           # Bash installer for macOS/Linux/WSL
├── install.ps1          # PowerShell installer for Windows
├── LICENSE              # MIT License
├── README.md            # This file
└── CONTRIBUTING.md      # Contribution guidelines
```

## 🔒 Security

- All downloads use HTTPS with TLS 1.2+
- Checksums are verified when available
- Scripts run with minimal required privileges
- No sensitive data is transmitted or stored

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🔗 Links

- 🦞 [OpenClaw Website](https://openclaw.ai)
- 📚 [Documentation](https://docs.openclaw.ai)
- 💻 [GitHub Repository](https://github.com/openclaw/openclaw)
- 🐛 [Issue Tracker](https://github.com/openclaw/openclaw/issues)
- 💬 [Discord Community](https://discord.gg/openclaw)

---

<p align="center">
  <sub>Built with 🦞 by the OpenClaw community</sub>
</p>
