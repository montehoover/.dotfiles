@REM Script to kick off the initial setup of a Windows computer
@REM This is a cmd script instead of powershell because pwsh requires changing the default Execution Policy on fresh installations.

@REM Old batch script convention to keep from echoing the normal lines to the screen
@echo off

echo Installing basic apps like Firefox, VSCode, Git, and Python...
powershell -noprofile -ExecutionPolicy Unrestricted -File windows\initial_setup.ps1

@REM This will need to be run as an administrator in order to make the symlink. I can probably fix that by running it in powershell instead...
echo Attempting to create symlink for powershell profile...
del %UserProfile%\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
mklink %UserProfile%\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 %UserProfile%\.dotfiles\windows\profile.ps1
echo Completed successfully.