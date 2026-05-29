# dotfiles

Cross-platform dotfiles bootstrap for GitHub Codespaces, Debian/Ubuntu Linux, and macOS.

## Usage

```bash
./install.sh
```

The installer:

- installs and configures `fish`
- keeps fish config in managed `conf.d` snippets instead of overwriting `config.fish`
- installs common CLI tools with Homebrew when available
- installs the Teleport `tsh` client
- works in GitHub Codespaces and other Debian/Ubuntu-based environments

## Test without changing the machine

```bash
DOTFILES_DRY_RUN=1 ./install.sh
```
