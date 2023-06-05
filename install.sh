#!/bin/bash

apt install build-essential procps curl file git

# Install Homebrew
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
# Add Homebrew to FISH config
echo 'eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> ~/.config/fish/config.fish
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"


# Install Fish shell using Homebrew
brew install gcc
brew install fish

# Set Fish as the default shell
echo '/home/linuxbrew/.linuxbrew/bin/fish' | sudo tee -a /etc/shells
chsh -s /home/linuxbrew/.linuxbrew/bin/fish
