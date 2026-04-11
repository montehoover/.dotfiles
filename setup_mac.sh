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

# Write content (from stdin) to PATH only if it differs from what's already
# there. Avoids touching mtimes on re-runs, which is what causes Chrome to
# re-evaluate External Extensions and Firefox to re-trigger managed-mode
# initialization (which appears to wipe browser cache/sessions).
#
# Usage:
#   write_if_changed PATH         <<EOF ... EOF   # normal write
#   write_if_changed PATH sudo    <<EOF ... EOF   # sudo write
#
# Returns 0 if the file was written (changed), 1 if it was already up-to-date.
write_if_changed() {
    local path="$1"
    local mode="${2:-}"  # "" or "sudo"
    local tmp
    tmp=$(mktemp)
    cat > "$tmp"
    if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
        rm -f "$tmp"
        return 1
    fi
    if [[ "$mode" == "sudo" ]]; then
        sudo install -m 644 "$tmp" "$path"
    else
        install -m 644 "$tmp" "$path"
    fi
    rm -f "$tmp"
    return 0
}

ARCH=$(uname -m)  # arm64 or x86_64

# =============================================================================
# Step 1: Xcode CLI Tools
# =============================================================================
print_header "Step 1: Xcode CLI Tools"

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
# Step 2: Homebrew
# =============================================================================
print_header "Step 2: Homebrew"

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
# Step 3: Brew Bundle (CLI tools + cask apps)
# =============================================================================
print_header "Step 3: Homebrew Packages"

echo "  Running brew bundle..."
brew bundle --file="$SCRIPT_DIR/Brewfile" || true

# Verify each expected formula/cask and report
for formula in git git-lfs gh mas; do
    if brew list --formula | grep -q "^${formula}$"; then
        echo "  ✓ $formula"
        SUCCEEDED+=("$formula")
    else
        try_or_assist "$formula" "" "" brew install "$formula"
    fi
done

# git-lfs: install global filter hooks (idempotent — gitconfig already has the
# filter section, but `git lfs install` is what registers the binary as the
# handler for new clones and verifies the install).
if command -v git-lfs &>/dev/null; then
    git lfs install --skip-repo &>/dev/null && {
        echo "  ✓ git-lfs hooks installed"
        SUCCEEDED+=("git-lfs hooks")
    } || {
        echo "  ✗ git lfs install failed"
        FAILED+=("git-lfs hooks")
    }
fi

for cask in claude iterm2 firefox google-chrome rectangle shottr alt-tab cursor; do
    if brew list --cask | grep -q "^${cask}$"; then
        echo "  ✓ $cask"
        SUCCEEDED+=("$cask")
    else
        try_or_assist "$cask" "" "" brew install --cask "$cask"
    fi
done

# =============================================================================
# Step 4: Nerd Fonts
# =============================================================================
print_header "Step 4: Nerd Fonts"

echo "  Installing Nerd Fonts..."
bash "$SCRIPT_DIR/install_fonts.sh"
echo "  ✓ Nerd Fonts"
SUCCEEDED+=("Nerd Fonts")

# =============================================================================
# Step 5: Mac App Store Apps
# =============================================================================
print_header "Step 5: Mac App Store Apps"

MAS_IDS=(462054704 462058435 462062816 784801555 985367838 823766827 803453959)
MAS_NAMES=("Microsoft Word" "Microsoft Excel" "Microsoft PowerPoint" "Microsoft OneNote" "Microsoft Outlook" "OneDrive" "Slack")

for i in "${!MAS_IDS[@]}"; do
    app_id="${MAS_IDS[$i]}"
    app_name="${MAS_NAMES[$i]}"
    if [ -d "/Applications/${app_name}.app" ] || mas list | grep -q "^ *${app_id} "; then
        echo "  ✓ $app_name (already installed)"
        SUCCEEDED+=("$app_name")
    else
        echo "  Installing $app_name..."
        if mas install "$app_id"; then
            echo "  ✓ $app_name"
            SUCCEEDED+=("$app_name")
        else
            echo "  ✗ $app_name failed — skipping."
            FAILED+=("$app_name")
        fi
    fi
done

# =============================================================================
# Step 6: Claude Code & Miniforge
# =============================================================================
print_header "Step 6: Dev Tools (Claude Code & Miniforge)"

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
            echo "  ✓ Miniforge installed (init handled by profile_shared; restart shell to activate)"
        fi
        rm -f "$MINIFORGE_INSTALLER"
    fi
fi

# =============================================================================
# Step 7: SSH Key & GitHub Auth
# =============================================================================
print_header "Step 7: SSH Key & GitHub Auth"

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

# Add GitHub host key to known_hosts
if ! grep -q "github.com" ~/.ssh/known_hosts 2>/dev/null; then
    ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
    echo "  ✓ Added GitHub host key to known_hosts"
else
    echo "  ✓ GitHub host key (already in known_hosts)"
fi

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
# Step 8: macOS Preferences
# =============================================================================
print_header "Step 8: macOS Preferences"

# Dock — skip if already configured (avoids restarting Dock on re-runs)
if [[ "$(defaults read com.apple.dock autohide 2>/dev/null)" != "1" ]] \
|| [[ "$(defaults read com.apple.dock tilesize 2>/dev/null)" != "64" ]] \
|| [[ "$(defaults read com.apple.dock show-recents 2>/dev/null)" != "0" ]] \
|| [[ "$(defaults read com.apple.dock wvous-br-corner 2>/dev/null)" != "14" ]]; then
    echo "  Configuring Dock..."
    defaults write com.apple.dock autohide -bool true
    defaults write com.apple.dock tilesize -int 64
    defaults write com.apple.dock show-recents -bool false
    defaults write com.apple.dock wvous-br-corner -int 14    # bottom-right = Quick Note
    defaults write com.apple.dock wvous-br-modifier -int 0
    killall Dock 2>/dev/null || true
    echo "  ✓ Dock (autohide, size 64, no recents, hot corner)"
else
    echo "  ✓ Dock preferences (already configured)"
fi
SUCCEEDED+=("Dock preferences")

# Finder — skip if already configured (avoids restarting Finder on re-runs)
if [[ "$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null)" != "1" ]] \
|| [[ "$(defaults read com.apple.finder ShowPathbar 2>/dev/null)" != "1" ]] \
|| [[ "$(defaults read com.apple.finder FXPreferredViewStyle 2>/dev/null)" != "Nlsv" ]] \
|| [[ "$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null)" != "1" ]]; then
    echo "  Configuring Finder..."
    defaults write com.apple.finder AppleShowAllFiles -bool true
    defaults write com.apple.finder ShowPathbar -bool true
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    killall Finder 2>/dev/null || true
    echo "  ✓ Finder (hidden files, path bar, list view, extensions)"
else
    echo "  ✓ Finder preferences (already configured)"
fi
SUCCEEDED+=("Finder preferences")

# Trackpad — skip if already configured
if has_trackpad; then
    if [[ "$(defaults read com.apple.AppleMultitouchTrackpad Clicking 2>/dev/null)" != "1" ]]; then
        echo "  Configuring Trackpad..."
        defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
        echo "  ✓ Trackpad (tap to click)"
    else
        echo "  ✓ Trackpad preferences (already configured)"
    fi
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

# iTerm2 — set Dynamic Profile as default
ITERM_PROFILE_GUID="7812A989-1897-40CB-BE81-10479BF68E9D"
if [[ "$(defaults read com.googlecode.iterm2 "Default Bookmark Guid" 2>/dev/null)" == "$ITERM_PROFILE_GUID" ]]; then
    echo "  ✓ iTerm2 default profile (already configured)"
else
    if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        # Running inside iTerm2 — it already knows about the dynamic profile
        defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$ITERM_PROFILE_GUID"
        echo "  ✓ iTerm2 default profile set to Monte (restart iTerm2 to apply)"
    elif [ -d "/Applications/iTerm.app" ]; then
        # Launch iTerm2 so it discovers the dynamic profile, then quit
        echo "  Launching iTerm2 briefly to load dynamic profile..."
        open -a iTerm
        for i in $(seq 1 30); do
            osascript -e 'tell application "iTerm2" to count windows' 2>/dev/null && break
            sleep 0.2
        done
        osascript -e 'quit app "iTerm2"'
        for i in $(seq 1 30); do
            pgrep -x iTerm2 >/dev/null || break
            sleep 0.2
        done
        defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "$ITERM_PROFILE_GUID"
        echo "  ✓ iTerm2 default profile set to Monte"
    else
        echo "  - iTerm2 not installed — skipping default profile setup."
    fi
fi
SUCCEEDED+=("iTerm2 default profile")

# =============================================================================
# Step 9: Browser Extensions
# =============================================================================
print_header "Step 9: Browser Extensions"

# Chrome: External Extensions JSON (silent install on next Chrome launch).
# Files are only written when content actually changes — re-running with
# identical content is a true no-op so Chrome doesn't re-evaluate extensions
# (which can wipe session/cache state).
CHROME_EXT_DIR="$HOME/Library/Application Support/Google/Chrome/External Extensions"
CHROME_LASTPASS="$CHROME_EXT_DIR/hdokiejnpimakedhajhdlcegeplioahd.json"
CHROME_ADBLOCK="$CHROME_EXT_DIR/cfhdojbkjhnklbpkdaibdccddilifddb.json"
chrome_changed=0

if [[ ! -f "$CHROME_LASTPASS" ]] || [[ ! -f "$CHROME_ADBLOCK" ]]; then
    mkdir -p "$CHROME_EXT_DIR"
fi

if write_if_changed "$CHROME_LASTPASS" <<'EOF'
{
  "external_update_url": "https://clients2.google.com/service/update2/crx"
}
EOF
then chrome_changed=1; fi

if write_if_changed "$CHROME_ADBLOCK" <<'EOF'
{
  "external_update_url": "https://clients2.google.com/service/update2/crx"
}
EOF
then chrome_changed=1; fi

if [[ "$chrome_changed" == "1" ]]; then
    echo "  ✓ Chrome extensions staged (LastPass + Adblock Plus — installed on next Chrome launch)"
else
    echo "  ✓ Chrome extensions (already staged, no changes)"
fi
SUCCEEDED+=("Chrome extensions")

# Firefox: policies.json (installs extensions on next Firefox launch).
# Lives inside the Firefox.app bundle, so a Firefox auto-update will erase it —
# re-run install.sh after an update to put it back. Only re-written when
# content changes, to avoid Firefox re-triggering managed-mode init.
FIREFOX_DIST="/Applications/Firefox.app/Contents/Resources/distribution"
FIREFOX_POLICIES="$FIREFOX_DIST/policies.json"
if [ -d "/Applications/Firefox.app" ]; then
    if [[ ! -d "$FIREFOX_DIST" ]]; then
        sudo mkdir -p "$FIREFOX_DIST"
    fi
    if write_if_changed "$FIREFOX_POLICIES" sudo <<'EOF'
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
    then
        echo "  ✓ Firefox extensions staged (LastPass + Adblock Plus — installed on next Firefox launch)"
    else
        echo "  ✓ Firefox extensions (already staged, no changes)"
    fi
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
