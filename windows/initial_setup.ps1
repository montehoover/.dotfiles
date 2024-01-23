
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

# All the basic Windows apps:
echo "Activating WSL..."
sudo wsl --install
echo "Installing git..."
winget install Git.Git
echo "Installing VSCode..."
winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'
echo "Installing Firefox..."
Mozilla.Firefox
echo "Installing LastPass browser extension"
winget install LogMeIn.LastPass
# echo "Installing Python and Conda..."
# winget install Anaconda.Miniconda3
# make conda not activate base by default
# conda config --set auto_activate_base false

# Powershell sugar
echo "Installing oh-my-posh for Powershell themes..."
winget install JanDeDobbeleer.OhMyPosh -s winget
echo "Installing posh-git..."
Install-Module posh-git -Scope CurrentUser -Force
Install-Module Terminal-Icons -Scope CurrentUser
Install-Module Z -Scope CurrentUser -AllowClobber
Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck
# scoop install fzf
# Install-Module PSFzf -Scope CurrentUser


