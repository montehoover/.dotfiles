# -------- Monte's edits: -----------
# ~/.profile is only run for login shells (when the terminal first starts up)
# when bash is the default shell. So it doesn't get called by zsh, or if switching
# from zsh to bash. Standard practice is to use ~/.profile to set environment
# variables and call ~/.bashrc. If we call ~/.profile from ~/.zshrc that works fine,
# but I prefer to leave this file with Ubuntu defaults and create ~/.profile_shared
# that is called by both ~/.bashrc and ~/.zshrc. Uncomment the following line to 
# check when this is being run:
# echo "Running ~/.profile..."
# 
# Below is the default ~/.profile from Ubuntu 20.04. The defaults can be found in
# /etc/skel
# -------- End Monte's edits -----------

# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi
