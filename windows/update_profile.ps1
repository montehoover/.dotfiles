echo "Attempting to create symlink for powershell profile..."
rm %UserProfile%\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
gsudo cmd /c mklink %UserProfile%\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 %UserProfile%\.dotfiles\windows\profile.ps1
echo "Completed successfully."