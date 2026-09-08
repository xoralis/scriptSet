#!/usr/bin/env bash

set -e

echo "========================================"
echo " Bash -> Zsh + Oh My Zsh + Powerlevel10k "
echo "========================================"


DATE=$(date +%Y%m%d_%H%M%S)



########################################
# 1. Backup
########################################

echo "[1/14] Backup bash config"


for f in \
~/.bashrc \
~/.bash_profile \
~/.profile \
~/.bash_history
do
    if [ -f "$f" ]; then
        cp "$f" "${f}.backup.${DATE}"
    fi
done



########################################
# 2. Install packages
########################################

echo "[2/14] Install packages"


if command -v apt >/dev/null 2>&1; then

    sudo apt update
    sudo apt install -y zsh git curl wget fzf


elif command -v dnf >/dev/null 2>&1; then

    sudo dnf install -y zsh git curl wget fzf


elif command -v pacman >/dev/null 2>&1; then

    sudo pacman -S --noconfirm zsh git curl wget fzf


elif command -v brew >/dev/null 2>&1; then

    brew install zsh git curl wget fzf

fi



########################################
# 3. Oh My Zsh
########################################

echo "[3/14] Install Oh My Zsh"


if [ ! -d "$HOME/.oh-my-zsh" ]; then

RUNZSH=no CHSH=no \
sh -c "$(curl -fsSL \
https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

fi



########################################
# 4. Powerlevel10k
########################################

echo "[4/14] Install Powerlevel10k"


P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"


if [ ! -d "$P10K_DIR" ]; then

git clone --depth=1 \
https://github.com/romkatv/powerlevel10k.git \
"$P10K_DIR"

fi



########################################
# 5. History migration
########################################

echo "[5/14] Migrate history"


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

fi



########################################
# 6. zprofile
########################################

echo "[6/14] Create zprofile"


cat > ~/.zprofile <<'EOF'

# migrated environment

typeset -U PATH


EOF


for f in ~/.bash_profile ~/.profile
do

    if [ -f "$f" ]; then

        grep '^export ' "$f" >> ~/.zprofile || true

    fi

done



########################################
# 7. zshrc
########################################

echo "[7/14] Create zshrc"


cat > ~/.zshrc <<'EOF'


export ZSH="$HOME/.oh-my-zsh"


# Powerlevel10k

ZSH_THEME="powerlevel10k/powerlevel10k"



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



# history

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
# 8. Alias
########################################

echo "[8/14] Migrate aliases"


for f in ~/.bashrc ~/.bash_profile
do

    if [ -f "$f" ]; then

        grep '^alias ' "$f" >> ~/.zshrc || true

    fi

done



########################################
# 9. Functions
########################################

echo "[9/14] Migrate functions"


if [ -f ~/.bashrc ]; then

grep -A30 \
-E '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' \
~/.bashrc >> ~/.zshrc || true

fi



########################################
# 10. Environment tools
########################################

echo "[10/14] Setup environments"



# nvm

if [ -d "$HOME/.nvm" ]; then

cat >> ~/.zshrc <<'EOF'


# nvm

export NVM_DIR="$HOME/.nvm"

[ -s "$NVM_DIR/nvm.sh" ] \
&& source "$NVM_DIR/nvm.sh"

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


eval "$(rbenv init - zsh)"

EOF

fi



# starship

if command -v starship >/dev/null 2>&1; then

cat >> ~/.zshrc <<'EOF'


eval "$(starship init zsh)"

EOF

fi



# cargo

if [ -f "$HOME/.cargo/env" ]; then

cat >> ~/.zshrc <<'EOF'


source "$HOME/.cargo/env"

EOF

fi



# sdkman

if [ -d "$HOME/.sdkman" ]; then

cat >> ~/.zshrc <<'EOF'


export SDKMAN_DIR="$HOME/.sdkman"

source "$SDKMAN_DIR/bin/sdkman-init.sh"

EOF

fi



########################################
# 11. Install plugins
########################################

echo "[11/14] Install plugins"


CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins



git clone \
https://github.com/zsh-users/zsh-autosuggestions \
"$CUSTOM/zsh-autosuggestions" \
2>/dev/null || true



git clone \
https://github.com/zsh-users/zsh-syntax-highlighting.git \
"$CUSTOM/zsh-syntax-highlighting" \
2>/dev/null || true



git clone \
https://github.com/agkozak/zsh-z \
"$CUSTOM/zsh-z" \
2>/dev/null || true



########################################
# 12. p10k config
########################################

echo "[12/14] Setup p10k"


if [ ! -f ~/.p10k.zsh ]; then

touch ~/.p10k.zsh

fi


cat >> ~/.zshrc <<'EOF'


[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

EOF



########################################
# 13. Default shell
########################################

echo "[13/14] Change shell"


ZSH=$(which zsh)


if [ -n "$ZSH" ]; then

chsh -s "$ZSH" || true

fi



########################################
# 14. Finish
########################################

echo
echo "========================================"
echo " Done!"
echo "========================================"

echo
echo "Next:"
echo
echo "1. Install Nerd Font:"
echo "   MesloLGS NF"
echo
echo "2. Restart:"
echo "   exec zsh"
echo
echo "3. Configure:"
echo "   p10k configure"
echo
echo "Test:"
echo "   history"
echo "   nvm -v"
echo "   node -v"
echo