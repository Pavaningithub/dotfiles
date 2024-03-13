#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export USERNAME=`whoami`

sudo apt-get update
sudo apt-get -y install --no-install-recommends apt-utils dialog 2>&1
sudo apt-get install -y \
  apt-transport-https \
  build-essential \
  curl \
  git \
  lsb-release \
  unzip 
  
sudo apt-add-repository ppa:fish-shell/release-3
sudo apt update
sudo apt install -y fish

sudo apt-get autoremove -y
sudo rm -rf /var/lib/apt/lists/*

# Define the path to the config.fish file
config_file="$HOME/.config/fish/config.fish"
abbr_file="$HOME/.config/fish/conf.d/abbr.fish"

# Create the directory if it doesn't exist
mkdir -p "$(dirname "$config_file")"
mkdir -p "$(dirname "$abbr_file")"

# Create the config.fish file or overwrite it if it already exists
cat <<EOF >"$config_file"
# Your config.fish content goes here
set -x KUBE_EDITOR 'code --wait'
set -x PATH "/home/linuxbrew/.linuxbrew/bin:$PATH"
EOF

# Create the abbr.fish file or overwrite it if it already exists
cat <<EOF >"$abbr_file"
abbr --add kg kubectl get
abbr --add k kubectl
abbr --add kgp kubectl get pods
abbr --add t terraform
abbr --add ti terraform init
abbr --add tp terraform plan
abbr --add ta terraform apply
abbr --add td terraform destroy
abbr --add cls clear
abbr --add gcm git commit -m
abbr --add gc git clone
abbr --add ns kubens
abbr --add ctx kubectx
EOF

# Install Fisher
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | .; fisher install jorgebucaran/fisher"
fish -c "fisher install evanlucas/fish-kubectl-completions"
fish -c "fisher install Ladicle/fish-kubectl-prompt"

# install homebrew
/bin/bash -c "(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" | /bin/bash

# install brew packages
# Running brew packages in the last as script is not proceeding post that
fish -c "brew install fzf"
fish -c "brew install exa"
fish -c "brew install lf"
fish -c "brew install kubectx"
fish -c "brew install yq"
fish -c "brew install jid"
fish -c "brew install istioctl"
fish -c "kubectl completion fish | ."
fish -c "brew install gcc"
