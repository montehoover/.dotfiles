#!/usr/bin/env bash

set -e

CONFIG="install.conf.yaml"
DOTBOT_DIR="dotbot"

DOTBOT_BIN="bin/dotbot"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${BASEDIR}"

# =============================================================================
# Show upcoming phases and confirm
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Dotfiles Installer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  This script will run the following phases:"
echo ""
echo "    I.  Update submodules"
echo "          oh-my-zsh, powerlevel10k, zsh-autosuggestions,"
echo "          zsh-syntax-highlighting, dotbot"
echo ""
echo "    II. Create symlinks"
echo "          bashrc, zshrc, gitconfig, profile, profile_shared,"
echo "          ssh/config, tmux.conf, iTerm2 profile"
echo ""
if [[ "$(uname)" == "Darwin" ]]; then
echo "   III. macOS setup"
echo "          1. Xcode CLI Tools"
echo "          2. Homebrew"
echo "          3. Homebrew Packages"
echo "                    CLI: git, gh, mas"
echo "                    Apps: Claude, iTerm2, Firefox, Chrome,"
echo "                          Rectangle, Shottr, AltTab, Cursor"
echo "          4. Nerd Fonts (7 families)"
echo "          5. Mac App Store Apps"
echo "                    Word, Excel, PowerPoint, OneNote,"
echo "                    Outlook, OneDrive, Slack"
echo "          6. Dev Tools"
echo "                    Claude Code, Miniforge (conda)"
echo "          7. SSH Key & GitHub Auth"
echo "          8. macOS Preferences"
echo "                    Dock: autohide, size 64, no recents, hot corner"
echo "                    Finder: hidden files, path bar, list view, extensions"
echo "                    Trackpad: tap to click"
echo "                    Screenshots: save to iCloud"
echo "          9. Browser Extensions"
echo "                    Chrome + Firefox: LastPass, Adblock Plus"
fi
echo ""
read -rp "  Press Enter to continue, or 'q' to quit: " choice
if [[ "$choice" == "q" ]]; then
    echo "  Aborted."
    exit 0
fi

# =============================================================================
# Phase I: Update submodules
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase I: Update submodules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! git -C "${DOTBOT_DIR}" submodule sync --quiet --recursive; then
    echo ""
    echo "==> Failed to sync dotbot submodule."
    echo "    The dotbot directory may be missing or corrupt."
    echo "    Try: git submodule update --init --recursive"
    exit 1
fi

if ! git submodule update --init --recursive "${DOTBOT_DIR}"; then
    echo ""
    echo "==> Failed to update submodules."
    echo "    Check your network connection, then re-run: bash install.sh"
    exit 1
fi

echo "  ✓ Submodules up to date"

# =============================================================================
# Phase II: Create symlinks
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Phase II: Create symlinks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ! "${BASEDIR}/${DOTBOT_DIR}/${DOTBOT_BIN}" -d "${BASEDIR}" -c "${CONFIG}" "${@}"; then
    echo ""
    echo "==> The install script failed during the symlink setup phase."
    echo "    Look at the messages above to see the exact file that had a problem."
    exit 1
fi

# =============================================================================
# Phase III: Platform-specific setup
# =============================================================================
if [[ "$(uname)" == "Darwin" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Phase III: macOS setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    bash "${BASEDIR}/setup_mac.sh"
fi
