
# This script only needs to be run once and all the commands are persistent.
# Ideally run this when setting up a new Windows environment
# Check out this setup if you need ideas:
# https://gist.github.com/mikepruett3/7ca6518051383ee14f9cf8ae63ba18a7
# https://github.com/mikepruett3/dotposh
# https://scriptingchris.tech/posts/how-i-setup-my-powershell-development-environment/
# symlinks: https://blogs.sap.com/2018/07/31/symbolic-links-in-powershell-extending-the-view-format/

# You can't run unsigned powershell scripts (including ones you write yourself) unless you change the default policy
echo "Updating ExecutionPolicy to allow running of Powershell scripts..."
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install gsudo, the "Windows sudo" so we can run commands that need an administrator prompt
echo "Installing sudo command line utility for Powershell..."
winget install gerardog.gsudo

# Right now we don't need Choco or Scoop for anything, but here's how to install them if we ever need:
# # Install Chocolatey
# sudo Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
# # Install Scoop
# irm get.scoop.sh | iex

# =============================================================================
# Core tools
# =============================================================================
echo "Activating WSL..."
sudo wsl --install
echo "Installing git..."
winget install Git.Git
echo "Installing GitHub CLI..."
winget install GitHub.cli
echo "Installing Node.js..."
winget install OpenJS.NodeJS.LTS

# =============================================================================
# Applications
# =============================================================================
echo "Installing Cursor..."
winget install Cursor.Cursor
echo "Installing Firefox..."
winget install Mozilla.Firefox
echo "Installing Chrome..."
winget install Google.Chrome
echo "Installing LastPass desktop app..."
winget install LogMeIn.LastPass
echo "Installing Slack..."
winget install SlackTechnologies.Slack
echo "Installing Microsoft Office..."
winget install Microsoft.Office

# =============================================================================
# Dev tools
# =============================================================================
echo "Installing Miniforge..."
winget install CondaForge.Miniforge3
# Make conda not activate base by default
# conda config --set auto_activate_base false

echo "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# =============================================================================
# Powershell modules
# =============================================================================
echo "Installing oh-my-posh for Powershell themes..."
winget install JanDeDobbeleer.OhMyPosh -s winget
echo "Installing posh-git..."
Install-Module posh-git -Scope CurrentUser -Force
Install-Module Terminal-Icons -Scope CurrentUser
Install-Module Z -Scope CurrentUser -AllowClobber
Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
# scoop install fzf
# Install-Module PSFzf -Scope CurrentUser

# =============================================================================
# SSH key + GitHub auth
# =============================================================================
echo "Setting up SSH key..."
if (-not (Test-Path "$env:USERPROFILE\.ssh\id_ed25519")) {
    ssh-keygen -t ed25519 -C "monte.b.hoover@gmail.com" -f "$env:USERPROFILE\.ssh\id_ed25519" -N '""'
    echo "SSH key generated."
} else {
    echo "SSH key already exists, skipping."
}

echo "Authenticating with GitHub (this will open your browser)..."
gh auth login
gh ssh-key add "$env:USERPROFILE\.ssh\id_ed25519.pub" --title "windows-setup-$env:COMPUTERNAME"

# =============================================================================
# Browser extensions
# =============================================================================
echo "Setting up Chrome extensions (LastPass + Adblock Plus)..."
$chromeExtPath = "HKCU:\SOFTWARE\Google\Chrome\Extensions"

# LastPass
New-Item -Path "$chromeExtPath\hdokiejnpimakedhajhdlcegeplioahd" -Force | Out-Null
Set-ItemProperty -Path "$chromeExtPath\hdokiejnpimakedhajhdlcegeplioahd" -Name "update_url" -Value "https://clients2.google.com/service/update2/crx"

# Adblock Plus
New-Item -Path "$chromeExtPath\cfhdojbkjhnklbpkdaibdccddilifddb" -Force | Out-Null
Set-ItemProperty -Path "$chromeExtPath\cfhdojbkjhnklbpkdaibdccddilifddb" -Name "update_url" -Value "https://clients2.google.com/service/update2/crx"

echo "Setting up Firefox extensions (LastPass + Adblock Plus)..."
$firefoxDist = "C:\Program Files\Mozilla Firefox\distribution"
if (Test-Path "C:\Program Files\Mozilla Firefox") {
    sudo New-Item -ItemType Directory -Path $firefoxDist -Force | Out-Null
    $policiesJson = @'
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
'@
    $policiesJson | sudo Out-File -FilePath "$firefoxDist\policies.json" -Encoding UTF8
    echo "Firefox extensions configured."
} else {
    echo "Firefox not found — skipping extension setup."
}

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "============================================"
echo "  Setup complete!"
echo ""
echo "  MANUAL STEPS REMAINING:"
echo "    - Launch Chrome and Firefox to trigger extension installation"
echo "    - Sign in to Microsoft Office (M365)"
echo "    - Sign in to: Slack, LastPass, Cursor"
echo "    - Restart shell to pick up new PATH entries"
echo "============================================"
echo ""
