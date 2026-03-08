# Repository Structure

```
openclaw-installer/
├── .gitignore              # Git ignore rules
├── install.sh              # Bash installer (macOS/Linux/WSL)
├── install.ps1             # PowerShell installer (Windows)
├── LICENSE                 # MIT License
├── README.md               # Main documentation
├── CONTRIBUTING.md         # Contribution guidelines
└── STRUCTURE.md            # This file
```

## File Purposes

### install.sh
Bash installer supporting:
- macOS 12+
- Linux (all major distros)
- WSL 1 & 2
- Automatic Node.js installation
- Automatic build tools installation
- Interactive and CI/CD modes

### install.ps1
PowerShell installer supporting:
- Windows 10/11
- PowerShell 5.1 and 7+
- Automatic Node.js installation
- Automatic Visual Studio Build Tools installation
- Winget/Chocolatey/Scoop integration

### README.md
Complete documentation including:
- Installation instructions
- Platform-specific notes
- Troubleshooting guide
- Environment variables reference

### CONTRIBUTING.md
Guidelines for contributors:
- How to report bugs
- How to suggest features
- Testing procedures
- Code style guidelines

### LICENSE
MIT License

### .gitignore
Excludes common files from version control
