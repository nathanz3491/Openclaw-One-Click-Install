#!/bin/bash
# OpenClaw Universal Installer
# Supports: macOS, Linux (all distros), WSL
# Usage: curl -fsSL https://openclaw.ai/install.sh | bash
#    or: wget -qO- https://openclaw.ai/install.sh | bash

set -euo pipefail

# Version
INSTALLER_VERSION="1.0.0"
REQUIRED_NODE_VERSION="22"

# Colors
BOLD='\033[1m'
ACCENT='\033[38;2;255;77;77m'
INFO='\033[38;2;136;146;176m'
SUCCESS='\033[38;2;0;229;204m'
WARN='\033[38;2;255;176;32m'
ERROR='\033[38;2;230;57;70m'
MUTED='\033[38;2;90;100;128m'
NC='\033[0m'

# Configuration
DEFAULT_TAGLINE="All your chats, one OpenClaw."
OPENCLAW_VERSION="${OPENCLAW_VERSION:-latest}"
INSTALL_METHOD="${OPENCLAW_INSTALL_METHOD:-npm}"
GIT_DIR="${OPENCLAW_GIT_DIR:-$HOME/openclaw}"
GIT_UPDATE="${OPENCLAW_GIT_UPDATE:-1}"
NO_ONBOARD="${OPENCLAW_NO_ONBOARD:-0}"
NO_PROMPT="${OPENCLAW_NO_PROMPT:-0}"
DRY_RUN="${OPENCLAW_DRY_RUN:-0}"
VERBOSE="${OPENCLAW_VERBOSE:-0}"
USE_BETA="${OPENCLAW_BETA:-0}"
NPM_LOGLEVEL="${OPENCLAW_NPM_LOGLEVEL:-error}"
SHARP_IGNORE_GLOBAL_LIBVIPS="${SHARP_IGNORE_GLOBAL_LIBVIPS:-1}"

# State
OS=""
ARCH=""
GUM=""
GUM_STATUS="skipped"
GUM_REASON=""
TMPFILES=()
LAST_NPM_INSTALL_CMD=""

# Cleanup
cleanup() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -rf "$f" 2>/dev/null || true
    done
}
trap cleanup EXIT

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

# UI Functions
ui_info() {
    local msg="$*"
    if [[ -n "$GUM" ]]; then
        "$GUM" log --level info "$msg"
    else
        echo -e "${MUTED}·${NC} ${msg}"
    fi
}

ui_warn() {
    local msg="$*"
    if [[ -n "$GUM" ]]; then
        "$GUM" log --level warn "$msg"
    else
        echo -e "${WARN}!${NC} ${msg}"
    fi
}

ui_success() {
    local msg="$*"
    if [[ -n "$GUM" ]]; then
        local mark
        mark="$("$GUM" style --foreground "#00e5cc" --bold "✓")"
        echo "${mark} ${msg}"
    else
        echo -e "${SUCCESS}✓${NC} ${msg}"
    fi
}

ui_error() {
    local msg="$*"
    if [[ -n "$GUM" ]]; then
        "$GUM" log --level error "$msg"
    else
        echo -e "${ERROR}✗${NC} ${msg}"
    fi
}

ui_section() {
    local title="$1"
    if [[ -n "$GUM" ]]; then
        "$GUM" style --bold --foreground "#ff4d4d" --padding "1 0" "$title"
    else
        echo ""
        echo -e "${ACCENT}${BOLD}${title}${NC}"
    fi
}

ui_celebrate() {
    local msg="$1"
    if [[ -n "$GUM" ]]; then
        "$GUM" style --bold --foreground "#00e5cc" "$msg"
    else
        echo -e "${SUCCESS}${BOLD}${msg}${NC}"
    fi
}

# Detection Functions
detect_downloader() {
    if command -v curl &>/dev/null; then
        echo "curl"
        return 0
    fi
    if command -v wget &>/dev/null; then
        echo "wget"
        return 0
    fi
    return 1
}

detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
        return 0
    elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        echo "linux"
        return 0
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
        return 0
    fi
    echo "unknown"
}

detect_arch() {
    case "$(uname -m 2>/dev/null || true)" in
        x86_64|amd64) echo "x86_64" ;;
        arm64|aarch64) echo "arm64" ;;
        i386|i686) echo "i386" ;;
        armv7l|armv7) echo "armv7" ;;
        armv6l|armv6) echo "armv6" ;;
        *) echo "unknown" ;;
    esac
}

detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "unknown"
    fi
}

detect_shell() {
    echo "${SHELL:-/bin/sh}"
}

is_root() {
    [[ "$EUID" -eq 0 ]] 2>/dev/null || [[ "$(id -u)" -eq 0 ]] 2>/dev/null
}

is_non_interactive() {
    [[ "${NO_PROMPT:-0}" == "1" ]] || [[ ! -t 0 ]] || [[ ! -t 1 ]]
}

is_tty() {
    if [[ -n "${NO_COLOR:-}" ]]; then
        return 1
    fi
    if [[ "${TERM:-dumb}" == "dumb" ]]; then
        return 1
    fi
    [[ -t 2 ]] || [[ -t 1 ]]
}

# Download Functions
DOWNLOADER=""

ensure_downloader() {
    if [[ -z "$DOWNLOADER" ]]; then
        DOWNLOADER="$(detect_downloader)" || {
            ui_error "Neither curl nor wget found. Please install one of them."
            exit 1
        }
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    ensure_downloader
    
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --proto '=https' --tlsv1.2 --retry 3 --retry-delay 1 -o "$output" "$url"
    else
        wget -q --https-only --secure-protocol=TLSv1_2 --tries=3 --timeout=20 -O "$output" "$url"
    fi
}

download_text() {
    local url="$1"
    ensure_downloader
    
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --proto '=https' --tlsv1.2 --retry 3 "$url"
    else
        wget -q --https-only --secure-protocol=TLSv1_2 --tries=3 --timeout=20 -O - "$url"
    fi
}

# Gum (UI enhancement) bootstrap
gum_bootstrap() {
    GUM=""
    GUM_STATUS="skipped"
    GUM_REASON=""
    
    if is_non_interactive; then
        GUM_REASON="non-interactive shell"
        return 1
    fi
    
    if ! is_tty; then
        GUM_REASON="no TTY support"
        return 1
    fi
    
    if command -v gum &>/dev/null; then
        GUM="gum"
        GUM_STATUS="found"
        GUM_REASON="already installed"
        return 0
    fi
    
    if ! command -v tar &>/dev/null; then
        GUM_REASON="tar not found"
        return 1
    fi
    
    local gum_version="${OPENCLAW_GUM_VERSION:-0.17.0}"
    local os arch asset tmpdir gum_path
    
    os="$(detect_os)"
    arch="$(detect_arch)"
    
    if [[ "$os" == "windows" ]] || [[ "$os" == "unknown" ]] || [[ "$arch" == "unknown" ]]; then
        GUM_REASON="unsupported platform"
        return 1
    fi
    
    # Normalize for gum releases
    [[ "$os" == "macos" ]] && os="Darwin"
    [[ "$os" == "linux" ]] && os="Linux"
    
    asset="gum_${gum_version}_${os}_${arch}.tar.gz"
    local base="https://github.com/charmbracelet/gum/releases/download/v${gum_version}"
    
    tmpdir="$(mktemp -d)"
    TMPFILES+=("$tmpdir")
    
    if ! download_file "${base}/${asset}" "$tmpdir/$asset" 2>/dev/null; then
        GUM_REASON="download failed"
        return 1
    fi
    
    if ! tar -xzf "$tmpdir/$asset" -C "$tmpdir" 2>/dev/null; then
        GUM_REASON="extract failed"
        return 1
    fi
    
    gum_path="$(find "$tmpdir" -type f -name gum 2>/dev/null | head -n1 || true)"
    if [[ -z "$gum_path" ]]; then
        GUM_REASON="binary not found"
        return 1
    fi
    
    chmod +x "$gum_path" 2>/dev/null || true
    if [[ ! -x "$gum_path" ]]; then
        GUM_REASON="not executable"
        return 1
    fi
    
    GUM="$gum_path"
    GUM_STATUS="installed"
    GUM_REASON="temporary"
    return 0
}

print_banner() {
    local tagline="${1:-$DEFAULT_TAGLINE}"
    
    if [[ -n "$GUM" ]]; then
        local title t t2
        title="$("$GUM" style --foreground "#ff4d4d" --bold "🦞 OpenClaw Installer")"
        t="$("$GUM" style --foreground "#8892b0" "$tagline")"
        t2="$("$GUM" style --foreground "#5a6480" "v${INSTALLER_VERSION}")"
        "$(printf '%s\n%s\n%s' "$title" "$t" "$t2")" | "$GUM" style --border rounded --border-foreground "#ff4d4d" --padding "1 2"
        echo ""
    else
        echo -e "${ACCENT}${BOLD}"
        echo "  🦞 OpenClaw Installer"
        echo -e "${NC}${INFO}  ${tagline}${NC}"
        echo -e "${MUTED}  v${INSTALLER_VERSION}${NC}"
        echo ""
    fi
}

# Node.js Functions
check_node_version() {
    local version
    version="$(node --version 2>/dev/null | sed 's/^v//' || echo "0.0.0")"
    local major="${version%%.*}"
    
    if [[ "$major" -ge "$REQUIRED_NODE_VERSION" ]]; then
        return 0
    fi
    return 1
}

get_node_install_command() {
    local pkg_manager="$(detect_package_manager)"
    
    case "$pkg_manager" in
        apt)
            echo "curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt-get install -y nodejs"
            ;;
        dnf|yum)
            echo "curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash - && sudo $pkg_manager install -y nodejs"
            ;;
        pacman)
            echo "sudo pacman -S nodejs npm"
            ;;
        apk)
            echo "sudo apk add nodejs npm"
            ;;
        brew)
            echo "brew install node@22"
            ;;
        *)
            echo "# Please install Node.js ${REQUIRED_NODE_VERSION}+ manually from https://nodejs.org/"
            ;;
    esac
}

install_nodejs() {
    ui_section "Installing Node.js ${REQUIRED_NODE_VERSION}+"
    
    local pkg_manager="$(detect_package_manager)"
    
    if [[ "$pkg_manager" == "brew" ]]; then
        if ! command -v brew &>/dev/null; then
            ui_info "Installing Homebrew..."
            /bin/bash -c "$(download_text 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh')"
        fi
        brew install node@22 2>/dev/null || brew link node@22 2>/dev/null || true
    elif [[ "$pkg_manager" == "apt" ]]; then
        ui_info "Setting up NodeSource repository..."
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        apt-get install -y nodejs
    elif [[ "$pkg_manager" == "dnf" ]] || [[ "$pkg_manager" == "yum" ]]; then
        ui_info "Setting up NodeSource repository..."
        curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
        "$pkg_manager" install -y nodejs
    elif [[ "$pkg_manager" == "pacman" ]]; then
        pacman -S --noconfirm nodejs npm
    elif [[ "$pkg_manager" == "apk" ]]; then
        apk add --no-cache nodejs npm
    else
        ui_error "Cannot auto-install Node.js. Please install manually:"
        echo "  https://nodejs.org/en/download/"
        return 1
    fi
    
    if ! check_node_version; then
        ui_error "Node.js installation failed or wrong version"
        return 1
    fi
    
    ui_success "Node.js $(node --version) installed"
}

# Build Tools Functions
needs_build_tools() {
    ! command -v make &>/dev/null || ! command -v python3 &>/dev/null || ! command -v g++ &>/dev/null
}

install_build_tools() {
    ui_section "Installing Build Tools"
    
    local pkg_manager="$(detect_package_manager)"
    
    case "$pkg_manager" in
        apt)
            apt-get update -qq
            apt-get install -y -qq build-essential python3 make g++ cmake
            ;;
        dnf)
            dnf install -y -q gcc gcc-c++ make cmake python3
            ;;
        yum)
            yum install -y -q gcc gcc-c++ make cmake python3
            ;;
        pacman)
            pacman -S --noconfirm base-devel python3 cmake
            ;;
        apk)
            apk add --no-cache build-base python3 cmake
            ;;
        zypper)
            zypper install -y -q gcc gcc-c++ make cmake python3
            ;;
        brew)
            brew install cmake python3 || true
            ;;
        *)
            ui_warn "Unknown package manager. Please install build tools manually:"
            ui_warn "  - make, gcc/g++, python3, cmake"
            return 1
            ;;
    esac
    
    ui_success "Build tools installed"
}

install_macos_build_tools() {
    if ! xcode-select -p &>/dev/null; then
        ui_info "Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        ui_warn "Please complete the Xcode CLI tools installation, then re-run this script"
        exit 0
    fi
    
    if ! command -v cmake &>/dev/null; then
        if command -v brew &>/dev/null; then
            brew install cmake
        else
            ui_warn "CMake not found. Install with: brew install cmake"
        fi
    fi
}

# OpenClaw Installation Functions
resolve_version() {
    if [[ "$USE_BETA" == "1" ]]; then
        echo "beta"
    elif [[ -n "$OPENCLAW_VERSION" ]]; then
        echo "$OPENCLAW_VERSION"
    else
        echo "latest"
    fi
}

install_via_npm() {
    local version="$1"
    local spec
    
    if [[ "$version" == "latest" ]]; then
        spec="openclaw"
    else
        spec="openclaw@$version"
    fi
    
    ui_section "Installing OpenClaw via npm"
    ui_info "Package: $spec"
    
    local npm_cmd=(npm --loglevel "$NPM_LOGLEVEL" --no-fund --no-audit install -g "$spec")
    
    if [[ "$VERBOSE" == "1" ]]; then
        "${npm_cmd[@]}"
    else
        local log="$(mktempfile)"
        if ! "${npm_cmd[@]}" >"$log" 2>&1; then
            ui_error "npm install failed"
            
            # Check for common issues
            if grep -q "EACCES\|permission denied" "$log"; then
                ui_warn "Permission error detected. Try:"
                ui_warn "  1. Run with sudo (not recommended)"
                ui_warn "  2. Fix npm permissions: https://docs.npmjs.com/resolving-eacces-permissions-errors"
                ui_warn "  3. Use nvm or fnm to manage Node versions"
            elif grep -q "make\|cmake\|python" "$log"; then
                ui_warn "Missing build tools. Attempting to install..."
                if [[ "$OS" == "macos" ]]; then
                    install_macos_build_tools
                else
                    install_build_tools
                fi
                ui_info "Retrying npm install..."
                "${npm_cmd[@]}"
            else
                tail -n 50 "$log" >&2 || true
            fi
            return 1
        fi
    fi
    
    ui_success "OpenClaw installed via npm"
}

install_via_git() {
    ui_section "Installing OpenClaw from Git"
    
    if [[ -d "$GIT_DIR" ]]; then
        if [[ "$GIT_UPDATE" == "1" ]]; then
            ui_info "Updating existing repository..."
            cd "$GIT_DIR"
            git pull --ff-only || true
        else
            ui_info "Using existing repository (updates disabled)"
        fi
    else
        ui_info "Cloning repository to $GIT_DIR..."
        git clone --depth 1 https://github.com/openclaw/openclaw.git "$GIT_DIR"
        cd "$GIT_DIR"
    fi
    
    ui_info "Installing dependencies..."
    
    # Check for pnpm
    if command -v pnpm &>/dev/null; then
        pnpm install --frozen-lockfile
    elif command -v npm &>/dev/null; then
        npm ci
    else
        ui_error "No package manager found (npm or pnpm)"
        return 1
    fi
    
    ui_info "Building OpenClaw..."
    
    if command -v pnpm &>/dev/null; then
        pnpm build
    else
        npm run build
    fi
    
    # Link for global access
    ui_info "Linking globally..."
    if command -v pnpm &>/dev/null; then
        pnpm link --global
    else
        npm link
    fi
    
    ui_success "OpenClaw installed from source"
}

# Onboarding
run_onboarding() {
    [[ "$NO_ONBOARD" == "1" ]] && return 0
    
    ui_section "Starting Onboarding"
    
    if command -v openclaw &>/dev/null; then
        openclaw onboard
    else
        ui_warn "openclaw command not found in PATH. You may need to:"
        ui_warn "  1. Restart your shell"
        ui_warn "  2. Add npm global bin to PATH"
        ui_warn "  3. Run: openclaw onboard"
    fi
}

# Main Functions
print_usage() {
    cat <<EOF
OpenClaw Universal Installer v${INSTALLER_VERSION}

Usage:
  curl -fsSL https://openclaw.ai/install.sh | bash
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- [options]

Options:
  --install-method <npm|git>    Installation method (default: npm)
  --version <version>           Specific version to install (default: latest)
  --beta                        Use beta version
  --git-dir <path>              Directory for git clone (default: ~/openclaw)
  --no-git-update               Don't update existing git checkout
  --no-onboard                  Skip onboarding wizard
  --no-prompt                   Non-interactive mode (for CI/CD)
  --dry-run                     Show what would be done
  --verbose                     Enable verbose output
  --help, -h                    Show this help

Environment Variables:
  OPENCLAW_INSTALL_METHOD       npm or git
  OPENCLAW_VERSION              Version or dist-tag
  OPENCLAW_BETA=1               Use beta channel
  OPENCLAW_GIT_DIR              Git checkout directory
  OPENCLAW_NO_ONBOARD=1         Skip onboarding
  OPENCLAW_NO_PROMPT=1          Non-interactive mode
  OPENCLAW_DRY_RUN=1            Dry run mode
  OPENCLAW_VERBOSE=1            Verbose output

Examples:
  # Default install
  curl -fsSL https://openclaw.ai/install.sh | bash

  # Install specific version
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --version 1.2.3

  # Install from git
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --install-method git

  # CI/CD non-interactive
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-prompt --no-onboard

For Windows PowerShell:
  iwr -useb https://openclaw.ai/install.ps1 | iex

EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --install-method|--method)
                INSTALL_METHOD="$2"
                shift 2
                ;;
            --npm)
                INSTALL_METHOD="npm"
                shift
                ;;
            --git|--github)
                INSTALL_METHOD="git"
                shift
                ;;
            --version)
                OPENCLAW_VERSION="$2"
                shift 2
                ;;
            --beta)
                USE_BETA="1"
                shift
                ;;
            --git-dir|--dir)
                GIT_DIR="$2"
                shift 2
                ;;
            --no-git-update)
                GIT_UPDATE="0"
                shift
                ;;
            --no-onboard)
                NO_ONBOARD="1"
                shift
                ;;
            --onboard)
                NO_ONBOARD="0"
                shift
                ;;
            --no-prompt)
                NO_PROMPT="1"
                shift
                ;;
            --dry-run)
                DRY_RUN="1"
                shift
                ;;
            --verbose)
                VERBOSE="1"
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                ui_warn "Unknown option: $1"
                shift
                ;;
        esac
    done
}

print_system_info() {
    ui_section "System Information"
    
    local node_version="Not installed"
    if command -v node &>/dev/null; then
        node_version="$(node --version)"
    fi
    
    local npm_version="Not installed"
    if command -v npm &>/dev/null; then
        npm_version="$(npm --version)"
    fi
    
    local git_version="Not installed"
    if command -v git &>/dev/null; then
        git_version="$(git --version | cut -d' ' -f3)"
    fi
    
    echo "  OS:        $OS"
    echo "  Arch:      $(detect_arch)"
    echo "  Shell:     $(detect_shell)"
    echo "  Node.js:   $node_version"
    echo "  npm:       $npm_version"
    echo "  Git:       $git_version"
    echo "  Installer: $INSTALL_METHOD"
    echo "  Version:   $(resolve_version)"
}

main() {
    parse_args "$@"
    
    # Detect OS
    OS="$(detect_os)"
    ARCH="$(detect_arch)"
    
    if [[ "$OS" == "unknown" ]]; then
        ui_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    if [[ "$OS" == "windows" ]]; then
        ui_error "Windows detected. Please use PowerShell:"
        echo "  iwr -useb https://openclaw.ai/install.ps1 | iex"
        exit 1
    fi
    
    # Setup Gum for nice UI
    gum_bootstrap
    
    # Print banner
    local taglines=(
        "Your terminal just grew claws"
        "All your chats, one OpenClaw"
        "AI automation for the command line"
        "Your personal AI assistant"
    )
    local random_tagline="${taglines[$RANDOM % ${#taglines[@]}]}"
    print_banner "$random_tagline"
    
    # Dry run check
    if [[ "$DRY_RUN" == "1" ]]; then
        ui_info "DRY RUN MODE - No changes will be made"
        print_system_info
        exit 0
    fi
    
    # Verbose mode
    if [[ "$VERBOSE" == "1" ]]; then
        set -x
    fi
    
    # Print system info
    print_system_info
    
    # Check prerequisites
    ui_section "Checking Prerequisites"
    
    # Check Node.js
    if ! check_node_version; then
        ui_warn "Node.js ${REQUIRED_NODE_VERSION}+ is required but not found"
        
        if is_non_interactive; then
            ui_error "Cannot install Node.js in non-interactive mode"
            ui_info "Install Node.js ${REQUIRED_NODE_VERSION}+ first:"
            ui_info "  $(get_node_install_command)"
            exit 1
        fi
        
        if [[ -n "$GUM" ]]; then
            if ! "$GUM" confirm "Install Node.js ${REQUIRED_NODE_VERSION}+?" --default=true; then
                ui_error "Node.js is required. Exiting."
                exit 1
            fi
        else
            read -p "Install Node.js ${REQUIRED_NODE_VERSION}+? [Y/n] " -n 1 -r
            echo
            if [[ ! "$REPLY" =~ ^[Yy]$ ]] && [[ -n "$REPLY" ]]; then
                ui_error "Node.js is required. Exiting."
                exit 1
            fi
        fi
        
        if ! install_nodejs; then
            ui_error "Failed to install Node.js"
            exit 1
        fi
    else
        ui_success "Node.js $(node --version) ✓"
    fi
    
    # Check for build tools (only for npm install)
    if [[ "$INSTALL_METHOD" == "npm" ]] && needs_build_tools; then
        ui_warn "Some build tools may be missing (make, python3, g++)"
        ui_info "These may be needed for native dependencies"
        
        if [[ "$OS" == "macos" ]]; then
            install_macos_build_tools
        elif ! is_non_interactive; then
            if [[ -n "$GUM" ]]; then
                if "$GUM" confirm "Install build tools?" --default=true; then
                    install_build_tools || true
                fi
            else
                read -p "Install build tools? [Y/n] " -n 1 -r
                echo
                if [[ "$REPLY" =~ ^[Yy]$ ]] || [[ -z "$REPLY" ]]; then
                    install_build_tools || true
                fi
            fi
        fi
    fi
    
    # Install OpenClaw
    local version
    version="$(resolve_version)"
    
    case "$INSTALL_METHOD" in
        npm)
            install_via_npm "$version"
            ;;
        git)
            install_via_git
            ;;
        *)
            ui_error "Unknown install method: $INSTALL_METHOD"
            exit 1
            ;;
    esac
    
    # Verify installation
    ui_section "Verifying Installation"
    
    if command -v openclaw &>/dev/null; then
        local installed_version
        installed_version="$(openclaw --version 2>/dev/null || echo "unknown")"
        ui_success "OpenClaw $installed_version is ready!"
        
        ui_info ""
        ui_info "Next steps:"
        ui_info "  1. Run 'openclaw onboard' to set up your AI assistant"
        ui_info "  2. Run 'openclaw --help' to see available commands"
        ui_info "  3. Visit https://docs.openclaw.ai for documentation"
        
        # Run onboarding if enabled
        run_onboarding
    else
        ui_warn "openclaw command not found after installation"
        ui_info "You may need to:"
        ui_info "  1. Restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
        ui_info "  2. Add npm global bin to your PATH:"
        ui_info "     export PATH=\"$(npm config get prefix)/bin:\$PATH\""
    fi
    
    ui_celebrate ""
    ui_celebrate "🦞 OpenClaw installation complete!"
    ui_celebrate ""
}

main "$@"
