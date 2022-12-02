# This file is on disk at $HOME\.dotfiles\windows\profile.ps1
# You might be seeing it symlinked at $HOME\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 or $HOME\\OneDrive\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1
# Since it is symlinked, feel free to edit this file wherever you find it, but be sure to commit any useful changes in the .dotfiles git repo.

echo "Running $profile"

# Choose oh-my-posh theme
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/montehoover.omp.json" | Invoke-Expression
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/pure.omp.json" | Invoke-Expression

Import-Module posh-git
Import-Module Terminal-Icons
Import-Module Z
# #"Fuzzy Finder" tool
# Import-Module PSFzf 
# #"Fuzzy Finder" configs
# Set-PSReadLineOption -PredictionSource History
# Set-PsFzfOption -PSReadLineChordProvider 'Ctrl+f' -PSreadLineChordReverseHistory 'Ctrl+r'


# If you decide to use Choco in the future:
# # Import the Chocolatey Profile that contains the necessary code to enable
# # tab-completions to function for `choco`.
# # Be aware that if you are missing these lines from your profile, tab completion
# # for `choco` will not function.
# # See https://ch0.co/tab-completion for details.
# $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
# if (Test-Path($ChocolateyProfile)) {
#   Import-Module "$ChocolateyProfile"
# }

# ssh-copy-id equivalent
Import-Module $HOME/.dotfiles/windows/Copy-SSHKey.ps1
Set-Alias -Name ssh-copy-id -Value Copy-SSHKey

# linux-like aliases
Set-Alias -Name grep  -Value findstr
Set-Alias -Name open  -Value start
Set-Alias -Name sudo  -Value gsudo
Set-Alias -Name less  -Value more
Set-Alias -Name zip   -Value Compress-Archive
Set-Alias -Name unzip -Value Expand-Archive

# More linux-like aliases, but powershell aliases can only be single words (even with quotes) so use functions instead:
function which {Get-Command -All $args}
function ll {Get-ChildItem -Force $args}

# Function so I can "rm -rf" some folder
# First remove the alias if it already exists
if (Get-alias rm -ErrorAction SilentlyContinue) {Remove-Item alias:rm}
# Notice that "rf" is treated as a single argument, so this won't work with "rm -f" or "rm -r".
function rm ([switch]$rf, $item) {
  if ($rf) {
    Remove-Item $item -Recurse -Force
  }
  else {
    Remove-Item $item
  }
}