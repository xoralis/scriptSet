#!/usr/bin/env bash

set -e


echo "======================================"
echo " Bash -> Zsh + Oh My Zsh Migration"
echo "======================================"


DATE=$(date +%Y%m%d_%H%M%S)



########################################
# 1. Backup
########################################

echo "[1/12] Backup bash files"


for f in \
~/.bashrc \
~/.bash_profile \
~/.profile \
~/.bash_history
do

    if [ -f "$f" ]; then

        cp "$f" "${f}.backup.${DATE}"
        echo "backup $f"

    fi

done



########################################
# 2. Install zsh
########################################

echo "[2/12] Install packages"


if command -v apt >/dev/null 2>&1; then

    sudo apt update
    sudo apt install -y zsh git curl


elif command -v dnf >/dev/null 2>&1; then

    sudo dnf install -y zsh git curl


elif command -v pacman >/dev/null 2>&1; then

    sudo pacman -S --noconfirm zsh git curl


elif command -v brew >/dev/null 2>&1; then

    brew install zsh git curl

fi



########################################
# 3. Install Oh My Zsh
########################################

echo "[3/12] Install Oh My Zsh"


if [ ! -d "$HOME/.oh-my-zsh" ]; then

RUNZSH=no CHSH=no \
sh -c "$(curl -fsSL \
https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

fi



########################################
# 4. History migration
########################################

echo "[4/12] Migrate bash history"


if [ -f ~/.bash_history ]; then


    if [ -f ~/.zsh_history ]; then
        cp ~/.zsh_history ~/.zsh_history.backup.$DATE
    fi


    awk '
    /^#[0-9]+$/ {
        t=substr($0,2)
        getline cmd
        print ": " t ":0;" cmd
    }
    ' ~/.bash_history > ~/.zsh_history


    chmod 600 ~/.zsh_history


    echo "history migrated"

else

    echo "No bash history found"

fi



########################################
# 5. zprofile
########################################

echo "[5/12] Create zprofile"


cat > ~/.zprofile <<'EOF'


# =========================
# Migrated environment
# =========================


typeset -U PATH


EOF



for f in ~/.bash_profile ~/.profile
do

    if [ -f "$f" ]; then

        grep '^export ' "$f" >> ~/.zprofile || true

    fi

done



########################################
# 6. zshrc
########################################

echo "[6/12] Create zshrc"


cat > ~/.zshrc <<'EOF'


# =========================
# Oh My Zsh
# =========================


export ZSH="$HOME/.oh-my-zsh"


ZSH_THEME="agnoster"


plugins=(
    git
    sudo
    docker
    kubectl
    fzf
    extract
    zsh-z
    zsh-autosuggestions
    zsh-syntax-highlighting
)


source $ZSH/oh-my-zsh.sh



# =========================
# History
# =========================


HISTFILE=~/.zsh_history

HISTSIZE=100000
SAVEHIST=100000


setopt extended_history
setopt append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_save_no_dups
setopt hist_reduce_blanks



EOF



########################################
# 7. Alias
########################################

echo "[7/12] Migrate aliases"


for f in ~/.bashrc ~/.bash_profile
do

if [ -f "$f" ]; then

grep '^alias ' "$f" >> ~/.zshrc || true

fi

done



########################################
# 8. Functions
########################################

echo "[8/12] Migrate functions"


if [ -f ~/.bashrc ]; then


grep -A20 \
-E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' \
~/.bashrc >> ~/.zshrc || true


fi



########################################
# 9. Dev environments
########################################

echo "[9/12] Setup environments"



# nvm

if [ -d "$HOME/.nvm" ]; then


cat >> ~/.zshrc <<'EOF'


# nvm

export NVM_DIR="$HOME/.nvm"


[ -s "$NVM_DIR/nvm.sh" ] \
&& source "$NVM_DIR/nvm.sh"


[ -s "$NVM_DIR/bash_completion" ] \
&& source "$NVM_DIR/bash_completion"


EOF

fi



# pyenv

if [ -d "$HOME/.pyenv" ]; then


cat >> ~/.zshrc <<'EOF'


# pyenv

export PYENV_ROOT="$HOME/.pyenv"

export PATH="$PYENV_ROOT/bin:$PATH"

eval "$(pyenv init - zsh)"


EOF

fi



# conda

if command -v conda >/dev/null 2>&1; then

conda init zsh

fi



# rbenv

if [ -d "$HOME/.rbenv" ]; then


cat >> ~/.zshrc <<'EOF'


# rbenv

eval "$(rbenv init - zsh)"


EOF


fi



# starship

if command -v starship >/dev/null 2>&1; then


cat >> ~/.zshrc <<'EOF'


# starship

eval "$(starship init zsh)"


EOF


fi



# cargo

if [ -f "$HOME/.cargo/env" ]; then


cat >> ~/.zshrc <<'EOF'


# cargo

source "$HOME/.cargo/env"


EOF


fi



# sdkman

if [ -d "$HOME/.sdkman" ]; then


cat >> ~/.zshrc <<'EOF'


# sdkman

export SDKMAN_DIR="$HOME/.sdkman"

source "$SDKMAN_DIR/bin/sdkman-init.sh"


EOF


fi




########################################
# 10. Install plugins
########################################

echo "[10/12] Install plugins"


CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}



# autosuggestions

if [ ! -d "$CUSTOM/plugins/zsh-autosuggestions" ]; then

git clone \
https://github.com/zsh-users/zsh-autosuggestions \
"$CUSTOM/plugins/zsh-autosuggestions"

fi



# syntax highlighting

if [ ! -d "$CUSTOM/plugins/zsh-syntax-highlighting" ]; then

git clone \
https://github.com/zsh-users/zsh-syntax-highlighting.git \
"$CUSTOM/plugins/zsh-syntax-highlighting"

fi



# z

if [ ! -d "$CUSTOM/plugins/zsh-z" ]; then

git clone \
https://github.com/agkozak/zsh-z \
"$CUSTOM/plugins/zsh-z"

fi



########################################
# 11. Default shell
########################################

echo "[11/12] Set default shell"


ZSH=$(which zsh)


if [ -n "$ZSH" ]; then

    chsh -s "$ZSH" || true

fi



########################################
# 12. Finish
########################################

echo
echo "======================================"
echo " Migration completed"
echo "======================================"
echo
echo "Run:"
echo
echo "  exec zsh"
echo
echo "Test:"
echo
echo "  echo \$SHELL"
echo "  history | tail"
echo "  nvm --version"
echo "  python --version"
echo