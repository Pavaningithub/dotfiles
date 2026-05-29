#!/usr/bin/env bash

set -euo pipefail

DRY_RUN="${DOTFILES_DRY_RUN:-0}"
BREW_AVAILABLE=0
BREW_BIN=""
APT_PREREQS_INSTALLED=0
PLATFORM=""
DISTRO=""
CODENAME=""

log() {
  printf '[dotfiles] %s\n' "$*"
}

warn() {
  printf '[dotfiles] warning: %s\n' "$*" >&2
}

fail() {
  printf '[dotfiles] error: %s\n' "$*" >&2
  exit 1
}

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '+'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
    return 0
  fi

  "$@"
}

run_bash() {
  local command="$1"

  if [ "$DRY_RUN" = "1" ]; then
    printf '+ bash -lc %q\n' "$command"
    return 0
  fi

  bash -lc "$command"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    return 0
  fi

  has_cmd sudo || fail "sudo is required for this installer on ${PLATFORM}."
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    run "$@"
  else
    run sudo "$@"
  fi
}

detect_platform() {
  case "$(uname -s)" in
    Darwin)
      PLATFORM="macos"
      ;;
    Linux)
      PLATFORM="linux"
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO="${ID:-linux}"
        CODENAME="${VERSION_CODENAME:-}"
      fi
      ;;
    *)
      fail "unsupported operating system: $(uname -s)"
      ;;
  esac
}

brew_candidate_paths() {
  printf '%s\n' \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew \
    "$HOME/.linuxbrew/bin/brew"
}

brew_shellenv_path() {
  if [ -n "$BREW_BIN" ]; then
    printf '%s' "$BREW_BIN"
    return 0
  fi

  if has_cmd brew; then
    BREW_BIN="$(command -v brew)"
    printf '%s' "$BREW_BIN"
    return 0
  fi

  while IFS= read -r candidate; do
    if [ -x "$candidate" ]; then
      BREW_BIN="$candidate"
      printf '%s' "$BREW_BIN"
      return 0
    fi
  done <<EOF
$(brew_candidate_paths)
EOF

  return 1
}

enable_brew() {
  if brew_path="$(brew_shellenv_path)"; then
    if [ "$DRY_RUN" = "1" ]; then
      log "would enable Homebrew from ${brew_path}"
    else
      eval "$("$brew_path" shellenv)"
    fi
    BREW_AVAILABLE=1
  fi
}

install_homebrew() {
  if brew_shellenv_path >/dev/null 2>&1; then
    enable_brew
    return 0
  fi

  if [ "$(id -u)" -eq 0 ]; then
    warn "skipping Homebrew installation because it should not be installed as root."
    return 0
  fi

  log "installing Homebrew"
  run_bash 'NONINTERACTIVE=1 CI=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  enable_brew
}

install_apt_prereqs() {
  if [ "$APT_PREREQS_INSTALLED" -eq 1 ]; then
    return 0
  fi

  ensure_sudo
  log "installing apt prerequisites"
  export DEBIAN_FRONTEND=noninteractive
  as_root apt-get update
  as_root apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    file \
    fish \
    git \
    gnupg \
    lsb-release \
    unzip
  APT_PREREQS_INSTALLED=1
}

install_fish() {
  if has_cmd fish; then
    log "fish already installed"
    return 0
  fi

  case "$PLATFORM" in
    linux)
      if has_cmd apt-get; then
        install_apt_prereqs
        return 0
      fi
      install_homebrew
      ;;
    macos)
      install_homebrew
      ;;
  esac

  if [ "$BREW_AVAILABLE" -eq 1 ]; then
    install_brew_formula fish
  fi

  has_cmd fish || fail "fish installation failed"
}

install_brew_formula() {
  local formula="$1"

  if [ "$BREW_AVAILABLE" -ne 1 ]; then
    warn "skipping ${formula}; Homebrew is unavailable."
    return 0
  fi

  if brew list "$formula" >/dev/null 2>&1; then
    log "${formula} already installed"
    return 0
  fi

  log "installing ${formula} with Homebrew"
  if ! run brew install "$formula"; then
    warn "failed to install ${formula} with Homebrew"
  fi
}

install_brew_cask() {
  local cask="$1"

  if [ "$BREW_AVAILABLE" -ne 1 ]; then
    warn "skipping ${cask}; Homebrew is unavailable."
    return 0
  fi

  if brew list --cask "$cask" >/dev/null 2>&1; then
    log "${cask} already installed"
    return 0
  fi

  log "installing ${cask} with Homebrew"
  if ! run brew install --cask "$cask"; then
    warn "failed to install ${cask} with Homebrew"
  fi
}

install_teleport() {
  if has_cmd tsh; then
    log "tsh already installed"
    return 0
  fi

  if [ "$PLATFORM" = "linux" ] && has_cmd apt-get && { [ "${DISTRO}" = "ubuntu" ] || [ "${DISTRO}" = "debian" ]; }; then
    ensure_sudo

    local apt_arch
    apt_arch="$(dpkg --print-architecture 2>/dev/null || true)"
    if [ -z "$apt_arch" ]; then
      case "$(uname -m)" in
        x86_64) apt_arch="amd64" ;;
        aarch64|arm64) apt_arch="arm64" ;;
        *) apt_arch="" ;;
      esac
    fi

    local repo_name="$DISTRO"
    if [ -z "$CODENAME" ]; then
      warn "Teleport apt repository skipped because the distro codename could not be detected."
    else
      log "installing Teleport tsh with apt"
      local keyring_dir="/etc/apt/keyrings"
      local keyring_file="${keyring_dir}/teleport-archive-keyring.asc"
      local temp_key
      local repo_entry="deb [signed-by=${keyring_file}"
      if [ -n "$apt_arch" ]; then
        repo_entry="${repo_entry} arch=${apt_arch}"
      fi
      repo_entry="${repo_entry}] https://apt.releases.teleport.dev/${repo_name} ${CODENAME} stable"

      as_root install -d -m 0755 "$keyring_dir"
      if [ "$DRY_RUN" = "1" ]; then
        printf '+ curl -fsSL https://apt.releases.teleport.dev/gpg -o %s\n' '/tmp/teleport-archive-keyring.asc'
        printf '+ sudo install -m 0644 %s %s\n' '/tmp/teleport-archive-keyring.asc' "$keyring_file"
        printf '+ printf %q %q | sudo tee /etc/apt/sources.list.d/teleport.list\n' '%s\n' "$repo_entry"
      else
        temp_key="$(mktemp)"
        curl -fsSL https://apt.releases.teleport.dev/gpg -o "$temp_key"
        as_root install -m 0644 "$temp_key" "$keyring_file"
        rm -f "$temp_key"
        printf '%s\n' "$repo_entry" | as_root tee /etc/apt/sources.list.d/teleport.list >/dev/null
      fi

      as_root apt-get update
      if as_root apt-get install -y teleport; then
        if [ "$DRY_RUN" = "1" ] || has_cmd tsh; then
          return 0
        fi
      fi

      warn "apt-based Teleport installation failed; falling back to Homebrew when available."
    fi
  fi

  install_homebrew
  if [ "$PLATFORM" = "macos" ]; then
    install_brew_cask tsh
  else
    install_brew_formula teleport
  fi

  if [ "$DRY_RUN" = "1" ]; then
    return 0
  fi

  has_cmd tsh || warn "tsh could not be installed automatically."
}

write_fish_configuration() {
  local fish_config_dir="${HOME}/.config/fish"
  local fish_conf_dir="${fish_config_dir}/conf.d"
  local env_file="${fish_conf_dir}/dotfiles-env.fish"
  local abbr_file="${fish_conf_dir}/dotfiles-abbr.fish"
  local brew_candidates=""

  log "writing fish configuration"
  mkdir -p "$fish_conf_dir"

  while IFS= read -r candidate; do
    brew_candidates="${brew_candidates} ${candidate}"
  done <<EOF
$(brew_candidate_paths)
EOF

  cat >"$env_file" <<'EOF'
# Managed by dotfiles/install.sh

if not set -q KUBE_EDITOR
    if type -q code
        set -gx KUBE_EDITOR "code --wait"
    else if type -q code-insiders
        set -gx KUBE_EDITOR "code-insiders --wait"
    else if type -q vim
        set -gx KUBE_EDITOR "vim"
    else if type -q nano
        set -gx KUBE_EDITOR "nano"
    end
end

for brew_bin in __BREW_CANDIDATES__
    if test -x "$brew_bin"
        eval ("$brew_bin" shellenv)
        break
    end
end
EOF
  perl -0pi -e 's#__BREW_CANDIDATES__#'"${brew_candidates}"'#g' "$env_file"

  cat >"$abbr_file" <<'EOF'
# Managed by dotfiles/install.sh

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
}

install_fisher_plugins() {
  has_cmd fish || return 0
  local plugin
  local fisher_file

  log "installing fish plugins"
  if ! fish -c 'functions -q fisher'; then
    if [ "$DRY_RUN" = "1" ]; then
      printf '+ curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish -o %s\n' '/tmp/fisher.fish'
      printf '+ fish -c %q\n' 'source /tmp/fisher.fish; and fisher install jorgebucaran/fisher'
    else
      fisher_file="$(mktemp)"
      curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish -o "$fisher_file"
      fish -c "source '$fisher_file'; and fisher install jorgebucaran/fisher"
      rm -f "$fisher_file"
    fi
  fi

  for plugin in evanlucas/fish-kubectl-completions Ladicle/fish-kubectl-prompt; do
    if ! run fish -c "fisher install ${plugin}"; then
      warn "failed to install fish plugin ${plugin}"
    fi
  done
}

write_kubectl_completion() {
  has_cmd fish || return 0
  has_cmd kubectl || return 0

  local completion_file="${HOME}/.config/fish/completions/kubectl.fish"
  run mkdir -p "$(dirname "$completion_file")"

  if [ "$DRY_RUN" = "1" ]; then
    printf '+ kubectl completion fish > %s\n' "$completion_file"
    return 0
  fi

  kubectl completion fish >"$completion_file"
}

install_brew_packages() {
  install_homebrew

  if [ "$BREW_AVAILABLE" -ne 1 ]; then
    warn "skipping optional Homebrew packages because Homebrew is unavailable."
    return 0
  fi

  install_brew_formula fzf
  install_brew_formula lf
  install_brew_formula kubectx
  install_brew_formula yq
  install_brew_formula jid
  install_brew_formula istioctl
  install_brew_formula gcc
}

main() {
  detect_platform
  log "detected platform: ${PLATFORM}${DISTRO:+ (${DISTRO})}"

  if [ "$PLATFORM" = "linux" ] && has_cmd apt-get; then
    install_apt_prereqs
  fi

  install_fish
  install_homebrew
  install_brew_packages
  install_teleport
  write_fish_configuration
  install_fisher_plugins
  write_kubectl_completion

  log "done"
}

main "$@"
