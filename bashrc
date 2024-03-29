# -------------------
# Auto-created from WSL Ubuntu 20.04 with edits by Monte
# Original can be found at /etc/skel
# 
# Startup order:
# If login shell (opening terminal, ssh, etc):
#     If ~/.bash_profile -> call it
#     else if ~/.bash_login -> call it
#     else if ~/.profile -> call it
#         By convention, ~/.profile will set environment variables and call ~/.bashrc
# else (if you just called exec bash or something):
#     Only ~/.bashrc gets called.
#
# ~/.bashrc should contain anything unique to bash (not applicable to zsh). I chose
# to make a file called ~/.profile_shared that both ~/.bashrc and ~/.zshrc call for
# shared suff.
# -------------------

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    # ----------- Monte's edit: ---------------
    # I'm commenting out the default so I can drop the user@hostname terms and put the '$' prompt on a new line
    # PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;34m\]\w\n\[\033[00m\]\$ '
    # ----------------------------------------
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# --- Monte commenting out on 9JUN22 ---
# some more ls aliases
# alias ll='ls -alF'
# alias la='ls -A'
# alias l='ls -CF'
# --- End Monte edit ---

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# ---------- Monte's edits: -----------

# Has aliases and environment variables
source ~/.profile_shared

# Use tab to cycle through options:
bind TAB:menu-complete
# -or- use tab to show all options:
# bind "set show-all-if-ambiguous on"

# Make above tab controls case-insensitive 
bind "set completion-ignore-case on"

# Turn off beep/bell:
bind 'set bell-style none'

# Change the prompt to show working directory  and then $ on line below
# Explanation:
# "\w" is for working directory
# "\[\033[01;34m\]" turns the thing after it blue
# "\$" is just the prompt symbol we choose
# "\[\033[00m\]" resets the color to white instead of blue
# Prompts also often include "\u@\h:" in front of this to display user and hostname
# You can also include ${debian_chroot:+($debian_chroot)} to show if you are using a chroot
# environment (usually won't show anything)
# PS1='${debian_chroot:+($debian_chroot)}\[\033[01;34m\]\w\n\[\033[00m\]\$ '
# A typical default you might see:
#PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '


# Colors for folders/files/executables in terminal:
# export CLICOLOR=1
# export LSCOLORS=GxFxCxDxBxegedabagaced

# alias ll="ls -la"

# ---------- End Monte's edits -----------

# ---------- Things added by installer scripts ----------
# Monte note: I changed "/home/monte" to be $HOME below so it works on other machines

