@REM Script to kick off the initial setup of a Windows computer
@REM This is a cmd script instead of powershell because pwsh requires changing the default Execution Policy on fresh installations.

@REM Old batch script convention to keep from echoing the normal lines to the screen
@echo off

echo Installing basic apps like Firefox, VSCode, Git, and Python...
powershell -noprofile -ExecutionPolicy Unrestricted -File windows\initial_setup.ps1
powershell -noprofile -ExecutionPolicy Unrestricted -File windows\update_profile.ps1