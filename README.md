# dotfile Management System utilzing stow

## In this repository

- nvim configuration (.config/nvim)
- zsh configuration (.zshrc)
- tmux configuration (.tmux.conf)

## How to

Clone the repository

```terminal
git clone https://www.github.com/gabeshin/dotfiles.git ~/dotfiles
```

Download and install [stow](https://www.gnu.org/software/stow/)

```terminal
brew install stow
```

Move to dotfiles directory and create symlink

```terminal
cd ~/dotfiles
stow .
```

### .zshrc

- oh-my-zsh needs to be installed

- powerlevel10k needs to be installed

* most of the plugins needs to be installed in $ZSH_CUSTOM/plugins

### .tmux.conf

- tmux needs to be installed
- tpm needs to be installed
