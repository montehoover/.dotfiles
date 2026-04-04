# Monte's Dotfiles Repo

This repo was initially created using the "init-dotfiles" script: https://github.com/Vaelatern/init-dotfiles

To set up a new machine:
1. `git clone https://github.com/montehoover/.dotfiles.git ~/.dotfiles`
2. `cd ~/.dotfiles && bash ./install.sh`

On macOS, this also installs Homebrew, apps (via brew/mas), dev tools (Claude Code, Miniforge), configures system preferences, and sets up browser extensions. On Windows, use `install.cmd` instead.
The install script is from [dotbot](https://github.com/anishathalye/dotbot), which is a submodule of this repo.

I'm using zsh with [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) as a plugin/template manager. I'm using a pretty limited set of plugins (see line 82 of [.zshrc](./zshrc)) including [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting). I like [powerlevel10k](https://github.com/romkatv/powerlevel10k) for a nice minimal theme. If I were to do this again I would use [antigen](https://github.com/zsh-users/antigen) instead of oh-my-zsh, but it is working fine now so I'm not going to mess with it. 

I almost never use tmux, but [tpm](https://github.com/tmux-plugins/tpm) works well as it's plugin manager and I mainly use it for the [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) plugin that comes bundled with it by default and to add the [dracula](https://github.com/dracula/tmux) theme.

I have a few aliases that I like in [.profile_shared](./profile_shared).

This repo also helps me sync the small basics like .gitconfig and .ssh configs. I also use this repo to carry around slurm/sbatch templates which I find handy.

## What Gets Installed (macOS)

**Via Homebrew (Brewfile):**
- git
- gh (GitHub CLI)
- mas (Mac App Store CLI)
- iTerm2
- Firefox
- Google Chrome
- Rectangle
- Shottr
- AltTab
- Cursor
- Claude

**Via Mac App Store (setup_mac.sh):**
- Microsoft Word, Excel, PowerPoint, OneNote, Outlook
- Microsoft OneDrive
- Slack

**Dev tools (setup_mac.sh):**
- Claude Code
- Miniforge (conda)

**Browser extensions (staged for install on next launch):**
- LastPass (Chrome + Firefox)
- Adblock Plus (Chrome + Firefox)

**Shell/terminal (via submodules and config):**
- Oh My Zsh
- zsh-autosuggestions
- zsh-syntax-highlighting
- Powerlevel10k theme
- Nerd Fonts (7 families)
- tpm (tmux plugin manager)
- tmux-sensible plugin
- Dracula tmux theme

**Also configured:**
- SSH key generation + GitHub auth
- macOS preferences (Dock autohide, Finder show hidden files/path bar/list view/extensions, tap-to-click, hot corner, iCloud screenshots)
