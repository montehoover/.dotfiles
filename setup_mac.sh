#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# macOS Setup Script
# =============================================================================
# Called by install.sh on macOS. Installs apps, dev tools, and configures
# system preferences. Safe to re-run — skips anything already installed.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUCCEEDED=()
SKIPPED=()
FAILED=()

# --- Helpers -----------------------------------------------------------------

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_exit_message() {
    echo ""
    echo "============================================"
    echo "  This script is safe to run again."
    echo "  It will skip anything already installed"
    echo "  and pick up where it left off."
    echo "============================================"
    echo ""
}

# Try a command. On failure: show error output, optionally open a helpful
# app/URL, prompt the user to retry/skip/quit.
#
# Usage:
#   try_or_assist "Name" "assist_cmd" "assist_msg" command arg1 arg2 ...
#   try_or_assist "Name" "" "" command arg1 arg2 ...
try_or_assist() {
    local name="$1"
    local assist_cmd="$2"
    local assist_msg="$3"
    shift 3

    # Capture output for error reporting
    local output
    if output=$("$@" 2>&1); then
        echo "  ✓ $name"
        SUCCEEDED+=("$name")
        return 0
    fi

    # First attempt failed
    echo ""
    echo "  ✗ $name failed."
    echo "    Error output:"
    echo "$output" | sed 's/^/      /'

    if [[ -n "$assist_cmd" ]]; then
        eval "$assist_cmd"
    fi

    if [[ -n "$assist_msg" ]]; then
        echo ""
        echo "    $assist_msg"
    fi

    echo ""
    read -rp "    Press Enter to retry, 's' to skip, or 'q' to quit: " choice

    if [[ "$choice" == "q" ]]; then
        print_exit_message
        exit 1
    fi

    if [[ "$choice" == "s" ]]; then
        SKIPPED+=("$name")
        return 1
    fi

    # Retry once
    if output=$("$@" 2>&1); then
        echo "  ✓ $name (on retry)"
        SUCCEEDED+=("$name")
        return 0
    else
        echo "  ✗ $name still failed — skipping."
        echo "    Error output:"
        echo "$output" | sed 's/^/      /'
        FAILED+=("$name")
        return 1
    fi
}

has_trackpad() {
    system_profiler SPUSBDataType SPBluetoothDataType 2>/dev/null | grep -qi trackpad
}

ARCH=$(uname -m)  # arm64 or x86_64

# =============================================================================
# Phase 1: Xcode CLI Tools
# =============================================================================
print_header "Phase 1: Xcode CLI Tools"

if xcode-select -p &>/dev/null; then
    echo "  ✓ Xcode CLI Tools (already installed)"
    SUCCEEDED+=("Xcode CLI Tools")
else
    echo "  Installing Xcode CLI Tools..."
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "    A dialog should have appeared. Click 'Install' and wait for it to finish."
    read -rp "    Press Enter when the installation is complete, or 'q' to quit: " choice
    if [[ "$choice" == "q" ]]; then
        print_exit_message
        exit 1
    fi
    if xcode-select -p &>/dev/null; then
        echo "  ✓ Xcode CLI Tools"
        SUCCEEDED+=("Xcode CLI Tools")
    else
        echo "  ✗ Xcode CLI Tools — could not verify installation."
        FAILED+=("Xcode CLI Tools")
    fi
fi

# =============================================================================
# Phase 2: Homebrew
# =============================================================================
print_header "Phase 2: Homebrew"

if command -v brew &>/dev/null; then
    echo "  ✓ Homebrew (already installed)"
    SUCCEEDED+=("Homebrew")
else
    echo "  Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for this session
    if [[ "$ARCH" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    if command -v brew &>/dev/null; then
        echo "  ✓ Homebrew"
        SUCCEEDED+=("Homebrew")
    else
        echo "  ✗ Homebrew install failed."
        FAILED+=("Homebrew")
        echo "  Cannot continue without Homebrew."
        print_exit_message
        exit 1
    fi
fi

# =============================================================================
# Phase 3: Brew Bundle (CLI tools + cask apps)
# =============================================================================
print_header "Phase 3: Homebrew Packages"

echo "  Running brew bundle..."
brew bundle --file="$SCRIPT_DIR/Brewfile" || true

# Verify each expected formula/cask and report
for formula in git gh mas; do
    if brew list --formula | grep -q "^${formula}$"; then
        echo "  ✓ $formula"
        SUCCEEDED+=("$formula")
    else
        try_or_assist "$formula" "" "" brew install "$formula"
    fi
done

for cask in claude iterm2 firefox google-chrome rectangle shottr alt-tab cursor; do
    if brew list --cask | grep -q "^${cask}$"; then
        echo "  ✓ $cask"
        SUCCEEDED+=("$cask")
    else
        try_or_assist "$cask" "" "" brew install --cask "$cask"
    fi
done

# =============================================================================
# Phase 4: Nerd Fonts
# =============================================================================
print_header "Phase 4: Nerd Fonts"

echo "  Installing Nerd Fonts..."
bash "$SCRIPT_DIR/install_fonts.sh"
echo "  ✓ Nerd Fonts"
SUCCEEDED+=("Nerd Fonts")

# =============================================================================
# Phase 5: Mac App Store Apps
# =============================================================================
print_header "Phase 5: Mac App Store Apps"

declare -A MAS_APPS=(
    [462054704]="Microsoft Word"
    [462058435]="Microsoft Excel"
    [462062816]="Microsoft PowerPoint"
    [784801555]="Microsoft OneNote"
    [462060435]="Microsoft Outlook"
    [823766827]="OneDrive"
    [803453959]="Slack"
)

for app_id in "${!MAS_APPS[@]}"; do
    app_name="${MAS_APPS[$app_id]}"
    if mas list | grep -q "^${app_id}"; then
        echo "  ✓ $app_name (already installed)"
        SUCCEEDED+=("$app_name")
    else
        try_or_assist "$app_name" \
            "open -a \"App Store\"" \
            "The App Store has been opened. Sign in if needed, then press Enter to retry." \
            mas install "$app_id"
    fi
done

# =============================================================================
# Phase 6: Claude Code & Miniforge
# =============================================================================
print_header "Phase 6: Dev Tools (Claude Code & Miniforge)"

# Claude Code
if command -v claude &>/dev/null; then
    echo "  ✓ Claude Code (already installed)"
    SUCCEEDED+=("Claude Code")
else
    echo "  Installing Claude Code (native installer)..."
    try_or_assist "Claude Code" "" "" \
        bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

# Miniforge
if command -v conda &>/dev/null; then
    echo "  ✓ Miniforge (already installed)"
    SUCCEEDED+=("Miniforge")
else
    echo "  Installing Miniforge..."
    MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-${ARCH}.sh"
    MINIFORGE_INSTALLER="/tmp/Miniforge3-MacOSX-${ARCH}.sh"
    if try_or_assist "Miniforge download" "" "" \
        curl -L -o "$MINIFORGE_INSTALLER" "$MINIFORGE_URL"; then
        if try_or_assist "Miniforge install" "" "" \
            bash "$MINIFORGE_INSTALLER" -b -p "$HOME/miniforge3"; then
            "$HOME/miniforge3/bin/conda" init zsh 2>/dev/null || true
            echo "  ✓ Miniforge initialized (restart shell to activate)"
        fi
        rm -f "$MINIFORGE_INSTALLER"
    fi
fi

# =============================================================================
# Phase 7: SSH Key & GitHub Auth
# =============================================================================
print_header "Phase 7: SSH Key & GitHub Auth"

# SSH key
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    echo "  ✓ SSH key (already exists)"
    SUCCEEDED+=("SSH key")
else
    echo "  Generating SSH key..."
    mkdir -p "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "monte.b.hoover@gmail.com" -f "$HOME/.ssh/id_ed25519" -N ""
    echo "  ✓ SSH key generated"
    SUCCEEDED+=("SSH key")
fi

eval "$(ssh-agent -s)" &>/dev/null
ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true

# GitHub auth
if gh auth status &>/dev/null; then
    echo "  ✓ GitHub CLI (already authenticated)"
    SUCCEEDED+=("GitHub auth")
else
    echo "  Authenticating with GitHub (this will open your browser)..."
    gh auth login
    if gh auth status &>/dev/null; then
        echo "  ✓ GitHub CLI authenticated"
        SUCCEEDED+=("GitHub auth")
    else
        echo "  ✗ GitHub auth failed — skipping."
        FAILED+=("GitHub auth")
    fi
fi

# Upload SSH key to GitHub
if gh auth status &>/dev/null; then
    echo "  Uploading SSH key to GitHub..."
    gh ssh-key add "$HOME/.ssh/id_ed25519.pub" --title "mac-setup-$(hostname -s)" 2>/dev/null && {
        echo "  ✓ SSH key uploaded to GitHub"
        SUCCEEDED+=("SSH key upload")
    } || {
        echo "  ✓ SSH key already on GitHub (or upload skipped)"
        SUCCEEDED+=("SSH key upload")
    }
fi

# =============================================================================
# Phase 8: macOS Preferences
# =============================================================================
print_header "Phase 8: macOS Preferences"

# Dock
echo "  Configuring Dock..."
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 64
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock wvous-br-corner -int 14    # bottom-right = Quick Note
defaults write com.apple.dock wvous-br-modifier -int 0
killall Dock 2>/dev/null || true
echo "  ✓ Dock (autohide, size 64, no recents, hot corner)"
SUCCEEDED+=("Dock preferences")

# Finder
echo "  Configuring Finder..."
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
killall Finder 2>/dev/null || true
echo "  ✓ Finder (hidden files, path bar, list view, extensions)"
SUCCEEDED+=("Finder preferences")

# Trackpad
if has_trackpad; then
    echo "  Configuring Trackpad..."
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
    echo "  ✓ Trackpad (tap to click)"
    SUCCEEDED+=("Trackpad preferences")
else
    echo "  - No trackpad detected — skipping tap-to-click."
fi

# Screenshots → iCloud
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
ICLOUD_SCREENSHOTS="$ICLOUD_DIR/Screenshots"
if [ -d "$ICLOUD_DIR" ]; then
    mkdir -p "$ICLOUD_SCREENSHOTS"
    defaults write com.apple.screencapture location "$ICLOUD_SCREENSHOTS"
    echo "  ✓ Screenshots (saving to iCloud Drive/Screenshots)"
    SUCCEEDED+=("Screenshot location")
else
    echo "  ✗ iCloud Drive not available — cannot set screenshot location."
    try_or_assist "iCloud screenshot location" \
        'open "x-apple.systempreferences:com.apple.AppleIDPrefPane"' \
        "Apple ID settings opened. Sign in and enable iCloud Drive, then press Enter to retry." \
        bash -c "[ -d \"$ICLOUD_DIR\" ] && mkdir -p \"$ICLOUD_SCREENSHOTS\" && defaults write com.apple.screencapture location \"$ICLOUD_SCREENSHOTS\""
fi

# =============================================================================
# Phase 9: Browser Extensions
# =============================================================================
print_header "Phase 9: Browser Extensions"

# Chrome: External Extensions JSON (silent install on next Chrome launch)
CHROME_EXT_DIR="$HOME/Library/Application Support/Google/Chrome/External Extensions"
mkdir -p "$CHROME_EXT_DIR"

cat > "$CHROME_EXT_DIR/hdokiejnpimakedhajhdlcegeplioahd.json" << 'EOF'
{
  "external_update_url": "https://clients2.google.com/service/update2/crx"
}
EOF

cat > "$CHROME_EXT_DIR/cfhdojbkjhnklbpkdaibdccddilifddb.json" << 'EOF'
{
  "external_update_url": "https://clients2.google.com/service/update2/crx"
}
EOF

echo "  ✓ Chrome extensions staged (LastPass + Adblock Plus — installed on next Chrome launch)"
SUCCEEDED+=("Chrome extensions")

# Firefox: policies.json (installs extensions on next Firefox launch)
FIREFOX_DIST="/Applications/Firefox.app/Contents/Resources/distribution"
if [ -d "/Applications/Firefox.app" ]; then
    sudo mkdir -p "$FIREFOX_DIST"
    sudo tee "$FIREFOX_DIST/policies.json" > /dev/null << 'EOF'
{
  "policies": {
    "Extensions": {
      "Install": [
        "https://addons.mozilla.org/firefox/downloads/latest/adblock-plus/latest.xpi",
        "https://addons.mozilla.org/firefox/downloads/latest/lastpass-password-manager/latest.xpi"
      ]
    }
  }
}
EOF
    echo "  ✓ Firefox extensions staged (LastPass + Adblock Plus — installed on next Firefox launch)"
    SUCCEEDED+=("Firefox extensions")
else
    echo "  - Firefox not found in /Applications — skipping extension setup."
    SKIPPED+=("Firefox extensions")
fi

# =============================================================================
# Summary
# =============================================================================
print_header "Setup Complete"

echo "  Succeeded: ${#SUCCEEDED[@]} items"
echo "  Skipped:   ${#SKIPPED[@]} items"
echo "  Failed:    ${#FAILED[@]} items"

if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "  Failed:"
    printf "    - %s\n" "${FAILED[@]}"
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo ""
    echo "  Skipped:"
    printf "    - %s\n" "${SKIPPED[@]}"
fi

echo ""
echo "  MANUAL STEPS REMAINING:"
echo "    [ ] Launch Chrome and Firefox once to trigger extension installation"
echo "    [ ] System Settings -> Internet Accounts -> Add email/calendar accounts"
echo "    [ ] Sign in to: Slack, OneDrive, Claude, Cursor"
echo "    [ ] Grant permissions when prompted: Rectangle, Shottr, AltTab"

# Verification commands
echo ""
echo "  VERIFY WITH:"
echo "    ssh -T git@github.com"
echo "    conda info"
echo "    brew list && brew list --cask"
echo "    mas list"

print_exit_message
