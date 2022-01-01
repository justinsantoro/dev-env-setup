#!/bin/bash

set -e

cd ~
echo "updating debian..."
apt update && apt-get -y dist-upgrade

echo "installing base packaged programs..."
apt -y install wget \
                git \
                gnupg2 \
                rng-tools \
                zsh \
                timewarrior \
                taskwarrior \
                at

echo "adding microsoft repository..."
wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
echo "installing powershell..."
apt update && apt -y install powershell

echo "installing gopass..."
wget https://github.com/gopasspw/gopass/releases/download/v1.13.0/gopass_1.13.0_linux_amd64.deb
sudo dpkg -i gopass_1.13.0_linux_amd64.deb

echo "installing summon..."
wget https://raw.githubusercontent.com/cyberark/summon/main/install.sh -O installsummon.sh
. ./installsummon.sh

echo "installing gopass summon provider..."
mkdir summon
mkdir /usr/local/lib/summon
wget https://github.com/gopasspw/gopass-summon-provider/releases/download/v1.12.0/gopass-summon-provider-1.12.0-linux-amd64.tar.gz
tar -xf ~/gopass-summon-provider-1.12.0-linux-amd64.tar.gz --directory summon
mv summon/gopass-summon-provider /usr/local/lib/summon/gopass
rm -r summon

echo "adding user..."
useradd -m -p $(openssl passwd -1 "$WSL_PASSWORD") -s /bin/zsh -G sudo $WSL_USER

echo "installing oh my zsh..."
wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O installomz.sh
ZSH=/home/$WSL_USER/.oh-my-zsh sh ./installomz.sh --unattended --keep-zshrc

echo "installing powerslevel10 zsh theme..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /home/$WSL_USER/.oh-my-zsh/custom/themes/powerlevel10k

echo "downloading dotfiles..."
if [[ -n "$GITHUB_PASSWORD" ]]; then
    echo -e '#!/bin/sh\nexec echo "$GITHUB_PASSWORD"' >> gitpass.sh
    chmod +x gitpass.sh
    export GIT_ASKPASS=/root/gitpass.sh
fi
cd /home/$WSL_USER
git init
git remote add origin $DOTFILES_REPO
git fetch
git reset --hard origin/main
git checkout main

echo "debian stetup done."
