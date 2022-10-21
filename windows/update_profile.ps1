echo "Attempting to create symlink for powershell profile..."
rm %UserProfile%\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
# create a symlink for the normal user profile
gsudo cmd /c mklink %UserProfile%\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 %UserProfile%\.dotfiles\windows\profile.ps1
# create a symlink for a weird profile that I got one time from VS Code's powershell extension
gsudo cmd /c mklink %UserProfile%\OneDrive\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1 %UserProfile%\.dotfiles\windows\profile.ps1
echo "Completed successfully."