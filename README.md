# dotfile Management System utilzing stow

## In this repository

- nvim configuration (.config/nvim)
- zsh configuration (.zshrc)

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
