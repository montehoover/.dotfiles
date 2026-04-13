#!/usr/bin/env bash
set -uo pipefail

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

# --- Sudo: ask once, keep alive for the entire run --------------------------

echo "  This script needs administrator privileges for a few steps."
echo "  You will only be prompted once."
echo ""
sudo -v

# Refresh sudo timestamp every 50 seconds until this script exits.
# Use `sudo -v` (interactive via /dev/tty) as fallback because Homebrew
# calls `sudo -k` after privileged operations, which silently invalidates
# the timestamp and makes `sudo -n -v` fail permanently.
while true; do sudo -n -v 2>/dev/null || sudo -v </dev/tty; sleep 50; done &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT

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

# Parallel arrays: REMEDY_NAMES[i] → REMEDY_MSGS[i].
# Printed in the summary so the user knows exactly what to fix.
REMEDY_NAMES=()
REMEDY_MSGS=()

# Try a command; on failure record it with an actionable remedy and continue.
#
# Usage:
#   try_cmd "Name" "remedy message" command arg1 arg2 ...
try_cmd() {
    local name="$1"
    local remedy="$2"
    shift 2

    local output
    if output=$("$@" 2>&1); then
        echo "  ✓ $name"
        SUCCEEDED+=("$name")
        return 0
    fi

    echo "  ✗ $name failed."
    [[ -n "$output" ]] && echo "$output" | sed 's/^/      /'
    FAILED+=("$name")
    if [[ -n "$remedy" ]]; then
        REMEDY_NAMES+=("$name")
        REMEDY_MSGS+=("$remedy")
    fi
    return 1
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

# Ensure ~/claude exists before iTerm2 dynamic profile references it
mkdir -p "$HOME/claude"

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

# Verify each expected formula and report
for formula in git git-lfs gh mas oven-sh/bun/bun lastpass-cli; do
    if brew list --formula | grep -q "^${formula}$"; then
        echo "  ✓ $formula"
        SUCCEEDED+=("$formula")
    else
        try_cmd "$formula" "Run: brew install $formula" brew install "$formula"
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

# Verify each expected cask. Check for the actual .app in /Applications,
# not just whether brew has it registered. If the app is missing (e.g.,
# "app is damaged" → Move to Trash), uninstall the stale registration
# and reinstall from scratch.
#
# Cask name → expected .app name (only where they differ)
cask_app_name() {
    case "$1" in
        google-chrome) echo "Google Chrome" ;;
        alt-tab)       echo "AltTab" ;;
        iterm2)        echo "iTerm" ;;
        *)             echo "$1" ;;
    esac
}

for cask in claude discord iterm2 firefox google-chrome rectangle shottr alt-tab cursor; do
    app_name="$(cask_app_name "$cask")"
    # Case-insensitive check for the .app bundle
    app_path=$(find /Applications -maxdepth 1 -iname "${app_name}.app" -print -quit 2>/dev/null)

    if [[ -n "$app_path" ]]; then
        echo "  ✓ $cask"
        SUCCEEDED+=("$cask")
    else
        # App missing — clear any stale brew registration and install fresh
        if brew list --cask 2>/dev/null | grep -q "^${cask}$"; then
            echo "  ↻ $cask registered in brew but app missing — reinstalling..."
            brew uninstall --cask --force "$cask" 2>/dev/null
        fi
        try_cmd "$cask" "Run: brew install --cask $cask" brew install --cask "$cask"
        # Strip quarantine from freshly installed app
        app_path=$(find /Applications -maxdepth 1 -iname "${app_name}.app" -print -quit 2>/dev/null)
        [[ -n "$app_path" ]] && xattr -cr "$app_path" 2>/dev/null
    fi
done

# Brew's cask installs call sudo -k, which invalidates our cached credential.
# Re-validate now so the keepalive can maintain it for the rest of the script.
sudo -n -v 2>/dev/null || sudo -v </dev/tty

# LastPass: log in now so credentials are available for Discord setup (Step 9).
# lpass was just installed above, so this is the earliest we can prompt.
if command -v lpass &>/dev/null && ! lpass status -q 2>/dev/null; then
    echo ""
    echo "  LastPass login is needed for Discord channel setup (Step 9)."
    read -rp "  Enter your LastPass email (or press Enter to skip): " lpass_email
    if [[ -n "$lpass_email" ]]; then
        lpass login "$lpass_email" || echo "  - LastPass login failed — Discord setup will be skipped."
    else
        echo "  - Skipping LastPass login."
    fi
fi

# =============================================================================
# Step 4: Nerd Fonts
# =============================================================================
print_header "Step 4: Nerd Fonts"

echo "  Installing Nerd Fonts..."
if bash "$SCRIPT_DIR/install_fonts.sh"; then
    echo "  ✓ Nerd Fonts"
    SUCCEEDED+=("Nerd Fonts")
else
    echo "  ✗ Nerd Fonts install failed."
    FAILED+=("Nerd Fonts")
    REMEDY_NAMES+=("Nerd Fonts")
    REMEDY_MSGS+=("Run: bash $SCRIPT_DIR/install_fonts.sh")
fi

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
    try_cmd "Claude Code" "Run: curl -fsSL https://claude.ai/install.sh | bash" \
        bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

# Miniforge
if command -v conda &>/dev/null || [ -d "$HOME/miniforge3" ]; then
    echo "  ✓ Miniforge (already installed)"
    SUCCEEDED+=("Miniforge")
else
    echo "  Installing Miniforge..."
    MINIFORGE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-${ARCH}.sh"
    MINIFORGE_INSTALLER="/tmp/Miniforge3-MacOSX-${ARCH}.sh"
    if try_cmd "Miniforge download" "Run: curl -L -o $MINIFORGE_INSTALLER $MINIFORGE_URL" \
        curl -L -o "$MINIFORGE_INSTALLER" "$MINIFORGE_URL"; then
        if try_cmd "Miniforge install" "Run: bash $MINIFORGE_INSTALLER -b -p $HOME/miniforge3" \
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
    if ssh-keygen -t ed25519 -C "monte.b.hoover@gmail.com" -f "$HOME/.ssh/id_ed25519" -N ""; then
        echo "  ✓ SSH key generated"
        SUCCEEDED+=("SSH key")
    else
        echo "  ✗ SSH key generation failed."
        FAILED+=("SSH key")
    fi
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
# Step 8: ai-sync (syncs ~/.claude config across machines)
# =============================================================================
# Pause the sudo keepalive — ai-sync's interactive prompts read from /dev/tty
# and the keepalive's fallback `sudo -v </dev/tty` races with them.
kill $SUDO_KEEPALIVE_PID 2>/dev/null; wait $SUDO_KEEPALIVE_PID 2>/dev/null

print_header "Step 8: ai-sync"

# The installer may symlink into ~/.local/bin when /usr/local/bin isn't writable
# and stdin isn't a tty (which is the case when piping curl | bash). Make sure
# that location is on PATH for the rest of this script.
export PATH="$HOME/.local/bin:$PATH"

if command -v ai-sync &>/dev/null; then
    echo "  ✓ ai-sync (already installed)"
    SUCCEEDED+=("ai-sync install")
else
    echo "  Installing ai-sync..."
    if curl -fsSL https://raw.githubusercontent.com/berlinguyinca/ai-sync/main/install.sh | bash; then
        hash -r 2>/dev/null || true
        if command -v ai-sync &>/dev/null; then
            echo "  ✓ ai-sync installed"
            SUCCEEDED+=("ai-sync install")
        else
            echo "  ✗ ai-sync installed but not found on PATH"
            FAILED+=("ai-sync install")
        fi
    else
        echo "  ✗ ai-sync install failed"
        FAILED+=("ai-sync install")
    fi
fi

# Bootstrap the sync repo — clones montehoover/ai-config and applies it to
# ~/.claude. Re-bootstraps with --force if the existing repo is broken (e.g.
# remote doesn't exist).
AISYNC_REPO="git@github.com:montehoover/ai-config.git"
if [ -d "$HOME/.ai-sync/.git" ] && command -v ai-sync &>/dev/null; then
    if ai-sync status &>/dev/null; then
        echo "  ✓ ai-sync sync repo (already bootstrapped)"
        SUCCEEDED+=("ai-sync bootstrap")
    else
        echo "  ai-sync repo exists but remote is broken — re-bootstrapping..."
        if ai-sync bootstrap --force "$AISYNC_REPO"; then
            echo "  ✓ ai-sync re-bootstrapped"
            SUCCEEDED+=("ai-sync bootstrap")
        else
            echo "  ✗ ai-sync re-bootstrap failed"
            FAILED+=("ai-sync bootstrap")
        fi
    fi
elif command -v ai-sync &>/dev/null; then
    echo "  Bootstrapping ai-sync from $AISYNC_REPO..."
    if ai-sync bootstrap "$AISYNC_REPO"; then
        echo "  ✓ ai-sync bootstrapped"
        SUCCEEDED+=("ai-sync bootstrap")
    else
        echo "  ✗ ai-sync bootstrap failed"
        FAILED+=("ai-sync bootstrap")
    fi
fi

# Resume sudo keepalive now that ai-sync interactive prompts are done.
sudo -n -v 2>/dev/null || sudo -v </dev/tty
while true; do sudo -n -v 2>/dev/null || sudo -v </dev/tty; sleep 50; done &
SUDO_KEEPALIVE_PID=$!

# =============================================================================
# Step 8b: ai-sync nightly LaunchAgent
# =============================================================================
print_header "Step 8b: ai-sync Nightly Sync (LaunchAgent)"

PLIST_LABEL="com.ai-sync.nightly"
PLIST_SRC="$SCRIPT_DIR/launchd/${PLIST_LABEL}.plist"
PLIST_DST="$HOME/Library/LaunchAgents/${PLIST_LABEL}.plist"

if [[ -f "$PLIST_SRC" ]]; then
    mkdir -p "$HOME/Library/LaunchAgents"
    # Expand {{HOME}} to actual home directory
    sed "s|{{HOME}}|$HOME|g" "$PLIST_SRC" > "$PLIST_DST"

    # Unload first if already loaded (ignore errors)
    launchctl unload "$PLIST_DST" 2>/dev/null || true
    if launchctl load "$PLIST_DST" 2>/dev/null; then
        echo "  ✓ ai-sync nightly LaunchAgent (daily at 2:00 AM)"
        SUCCEEDED+=("ai-sync LaunchAgent")
    else
        echo "  ✗ Failed to load ai-sync LaunchAgent"
        FAILED+=("ai-sync LaunchAgent")
        REMEDY_NAMES+=("ai-sync LaunchAgent")
        REMEDY_MSGS+=("Run: launchctl load $PLIST_DST")
    fi
else
    echo "  ✗ Plist template not found at $PLIST_SRC"
    FAILED+=("ai-sync LaunchAgent")
fi

# =============================================================================
# Step 9: Claude Code Discord Channel
# =============================================================================
print_header "Step 9: Claude Code Discord Channel"

DISCORD_CHANNEL_DIR="$HOME/.claude/channels/discord"
DISCORD_ENV="$DISCORD_CHANNEL_DIR/.env"
DISCORD_ACCESS="$DISCORD_CHANNEL_DIR/access.json"
LPASS_NOTE="claude-code-discord"

# 9a. Plugin install (fallback — ai-sync usually brings this in)
if grep -q '"discord@claude-plugins-official"' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null; then
    echo "  ✓ Discord plugin (already installed)"
    SUCCEEDED+=("Discord plugin")
else
    echo "  Installing Discord plugin..."
    claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
    if claude plugin install -s user discord@claude-plugins-official; then
        echo "  ✓ Discord plugin installed"
        SUCCEEDED+=("Discord plugin")
    else
        echo "  ✗ Discord plugin install failed"
        FAILED+=("Discord plugin")
    fi
fi

# 9b. Bot token from LastPass → .env
if [[ -f "$DISCORD_ENV" ]] && grep -q "^DISCORD_BOT_TOKEN=" "$DISCORD_ENV"; then
    echo "  ✓ Discord bot token (already configured)"
    SUCCEEDED+=("Discord bot token")
else
    echo "  Fetching Discord bot token from LastPass note '$LPASS_NOTE'..."
    mkdir -p "$DISCORD_CHANNEL_DIR"

    lpass_blob=""
    if command -v lpass &>/dev/null && lpass status -q 2>/dev/null; then
        lpass_blob=$(lpass show --notes "$LPASS_NOTE" 2>/dev/null) || true
    fi

    token=$(echo "$lpass_blob" | grep "^DISCORD_BOT_TOKEN=" | cut -d= -f2-)

    if [[ -n "$token" ]]; then
        echo "DISCORD_BOT_TOKEN=$token" > "$DISCORD_ENV"
        chmod 600 "$DISCORD_ENV"
        echo "  ✓ Discord bot token written from LastPass"
        SUCCEEDED+=("Discord bot token")
    else
        echo "  ✗ Discord bot token not found (LastPass CLI not logged in or note missing)."
        FAILED+=("Discord bot token")
        REMEDY_NAMES+=("Discord bot token")
        REMEDY_MSGS+=("Run: lpass login <email> && re-run install.sh, or manually write DISCORD_BOT_TOKEN=<token> to $DISCORD_ENV")
    fi
fi

# 9c. Access config (user ID + group IDs from LastPass → access.json)
if [[ -f "$DISCORD_ACCESS" ]]; then
    echo "  ✓ Discord access config (already configured)"
    SUCCEEDED+=("Discord access config")
else
    echo "  Building Discord access config from LastPass note '$LPASS_NOTE'..."
    mkdir -p "$DISCORD_CHANNEL_DIR"

    lpass_blob=""
    if command -v lpass &>/dev/null && lpass status -q 2>/dev/null; then
        lpass_blob=$(lpass show --notes "$LPASS_NOTE" 2>/dev/null) || true
    fi

    user_id=$(echo "$lpass_blob" | grep "^DISCORD_USER_ID=" | cut -d= -f2-)
    group_ids_raw=$(echo "$lpass_blob" | grep "^DISCORD_GROUP_IDS=" | cut -d= -f2-)

    if [[ -n "$user_id" ]] && [[ -n "$group_ids_raw" ]]; then
        # Build groups object from comma-separated IDs
        groups_json="{"
        first=true
        IFS=',' read -ra gids <<< "$group_ids_raw"
        for gid in "${gids[@]}"; do
            gid=$(echo "$gid" | tr -d ' ')
            if [[ "$first" == true ]]; then
                first=false
            else
                groups_json+=","
            fi
            groups_json+="
    \"$gid\": {
      \"requireMention\": false,
      \"allowFrom\": [
        \"$user_id\"
      ]
    }"
        done
        groups_json+="
  }"

        cat > "$DISCORD_ACCESS" <<EOFACCESS
{
  "dmPolicy": "pairing",
  "allowFrom": [
    "$user_id"
  ],
  "groups": $groups_json,
  "pending": {}
}
EOFACCESS
        echo "  ✓ Discord access config written from LastPass"
        SUCCEEDED+=("Discord access config")
    else
        echo "  - Discord access config skipped (user ID or group IDs not found in LastPass)."
        echo "    To set up manually: launch claude_c, DM your bot, run /discord:access pair <code>,"
        echo "    then /discord:access group add <channelId> for each channel."
        SKIPPED+=("Discord access config")
    fi
fi

# =============================================================================
# Step 10: macOS Preferences
# =============================================================================
print_header "Step 10: macOS Preferences"

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
    FAILED+=("iCloud screenshot location")
    REMEDY_NAMES+=("iCloud screenshot location")
    REMEDY_MSGS+=("Sign in to iCloud in System Settings → Apple ID, enable iCloud Drive, then re-run install.sh")
fi

# iTerm2 — generate dynamic profile with correct $HOME and set as default
ITERM_PROFILE_GUID="7812A989-1897-40CB-BE81-10479BF68E9D"
ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
ITERM_DYNAMIC_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ITERM_PROFILE_SRC="$SCRIPT_DIR/iterm2/monte-profile.json"
ITERM_PROFILE_DST="$ITERM_DYNAMIC_DIR/monte-profile.json"

# Generate the dynamic profile with $HOME expanded (iTerm2 needs absolute paths)
mkdir -p "$ITERM_DYNAMIC_DIR"
# Remove old symlink from previous dotbot-managed installs
[ -L "$ITERM_PROFILE_DST" ] && rm "$ITERM_PROFILE_DST"
sed "s|__HOME__|$HOME|g" "$ITERM_PROFILE_SRC" > "$ITERM_PROFILE_DST"
echo "  ✓ iTerm2 dynamic profile generated with home=$HOME"

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
# iTerm2 caches dynamic profiles into New Bookmarks, which can override the
# dynamic profile's working directory. Force the correct values in the cache.
if [ -f "$ITERM_PLIST" ]; then
    PROFILE_COUNT=$(/usr/libexec/PlistBuddy -c "Print :New\ Bookmarks" "$ITERM_PLIST" 2>/dev/null | grep -c "Dict")
    for (( i=0; i<PROFILE_COUNT; i++ )); do
        CACHED_GUID=$(/usr/libexec/PlistBuddy -c "Print :New\ Bookmarks:$i:Guid" "$ITERM_PLIST" 2>/dev/null)
        if [[ "$CACHED_GUID" == "$ITERM_PROFILE_GUID" ]]; then
            /usr/libexec/PlistBuddy -c "Set :New\ Bookmarks:$i:Custom\ Directory Yes" "$ITERM_PLIST"
            /usr/libexec/PlistBuddy -c "Set :New\ Bookmarks:$i:Working\ Directory $HOME/claude" "$ITERM_PLIST"
            echo "  ✓ iTerm2 working directory set to ~/claude"
            break
        fi
    done
fi
SUCCEEDED+=("iTerm2 default profile")

# =============================================================================
# Step 11: Browser Configuration (Extensions + Policies)
# =============================================================================
print_header "Step 11: Browser Configuration"

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

# Chrome: disable "Hold ⌘Q to Quit" so it behaves like every other app.
# Chrome ignores macOS defaults for this; it reads browser.confirm_to_quit
# from its own Local State JSON. Must be set while Chrome is not running.
CHROME_LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"
if [ -f "$CHROME_LOCAL_STATE" ]; then
    if pgrep -x "Google Chrome" >/dev/null; then
        echo "  - Chrome hold-⌘Q: skipped (quit Chrome first, then re-run install.sh)"
    else
        python3 -c "
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
d.setdefault('browser', {})['confirm_to_quit'] = False
with open(path, 'w') as f:
    json.dump(d, f, indent=2)
" "$CHROME_LOCAL_STATE"
        echo "  ✓ Chrome hold-⌘Q-to-quit disabled"
    fi
else
    echo "  - Chrome hold-⌘Q: skipped (launch Chrome once first to create profile)"
fi

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
    },
    "SearchEngines": {
      "Default": "DuckDuckGo"
    },
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false
  }
}
EOF
    then
        echo "  ✓ Firefox policies staged (extensions, DuckDuckGo search, no password saving)"
    else
        echo "  ✓ Firefox policies (already staged, no changes)"
    fi
    SUCCEEDED+=("Firefox policies")
else
    echo "  - Firefox not found in /Applications — skipping Firefox configuration."
    SKIPPED+=("Firefox policies")
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
    for item in "${FAILED[@]}"; do
        echo "    - $item"
        for i in "${!REMEDY_NAMES[@]}"; do
            if [[ "${REMEDY_NAMES[$i]}" == "$item" ]]; then
                echo "      Fix: ${REMEDY_MSGS[$i]}"
                break
            fi
        done
    done
fi

if [ ${#SKIPPED[@]} -gt 0 ]; then
    echo ""
    echo "  Skipped:"
    printf "    - %s\n" "${SKIPPED[@]}"
fi

echo ""
echo "  MANUAL STEPS REMAINING:"
echo "    [ ] Launch Chrome and Firefox once to trigger extension installation"
echo "    [ ] System Settings → Internet Accounts → Add email/calendar accounts"
echo "    [ ] Sign in to: Slack, OneDrive, Claude, Cursor"
echo "    [ ] Grant permissions when prompted: Rectangle, Shottr, AltTab"

discord_incomplete=false
for item in ${FAILED[@]+"${FAILED[@]}"} ${SKIPPED[@]+"${SKIPPED[@]}"}; do
    case "$item" in Discord*) discord_incomplete=true; break ;; esac
done
if $discord_incomplete; then
    echo "    [ ] Run: lpass login <email>, then re-run install.sh to set up Discord for Claude Code"
else
    echo "    [ ] Verify Discord channel: launch claude_c, DM your bot to test"
fi

# Verification commands
echo ""
echo "  VERIFY WITH:"
echo "    ssh -T git@github.com"
echo "    conda info"
echo "    brew list"
echo "    mas list"

print_exit_message
