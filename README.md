# Monte's Dotfiles Repo

This repo was initially created using the "init-dotfiles" script: https://github.com/Vaelatern/init-dotfiles

To run this on a new machine:
1. git clone https://github.com/montehoover/.dotfiles.git
2. bash ./install

The install script is from [dotbot](https://github.com/anishathalye/dotbot), which is a submodule of this repo.

I'm using zsh with [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh) as a plugin/template manager. I'm using a pretty limited set of plugins (see line 82 of [.zshrc](./zshrc)) including [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting). I like [powerlevel10k](https://github.com/romkatv/powerlevel10k) for a nice minimal theme. If I were to do this again I would use [antigen](https://github.com/zsh-users/antigen) instead of oh-my-zsh, but it is working fine now so I'm not going to mess with it. 

I almost never use tmux, but [tpm](https://github.com/tmux-plugins/tpm) works well as it's plugin manager and I mainly use it for the [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) plugin that comes bundled with it by default and to add the [dracula](https://github.com/dracula/tmux) theme.

I have a few aliases that I like in [.profile_shared](./profile_shared).

This repo also helps me sync the small basics like .gitconfig and .ssh configs. I also use this repo to carry around slurm/sbatch templates which I find handy.