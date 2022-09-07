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

# linux-like aliases
Set-Alias -Name grep  -Value findstr
Set-Alias -Name ll    -Value ls
Set-Alias -Name open  -Value start
Set-Alias -Name sudo  -Value gsudo
Set-Alias -Name less  -Value more
Set-Alias -Name zip   -Value Compress-Archive
Set-Alias -Name unzip -Value Expand-Archive

function which {Get-Command -All $args}

# Function so I can "rm -rf" some folder
if (Get-alias rm -ErrorAction SilentlyContinue) {Remove-Item alias:rm}
function rm ([switch]$rf, $item) {
  if ($rf) {
    Remove-Item $item -Recurse -Force
  }
  else {
    Remove-Item $item
  }
}