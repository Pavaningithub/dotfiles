# dotfiles

Cross-platform dotfiles bootstrap for GitHub Codespaces, Linux, Ubuntu, and macOS.

## Usage

```bash
bash /tmp/workspace/Pavaningithub/dotfiles/install.sh
```

The installer:

- installs and configures `fish`
- keeps fish config in managed `conf.d` snippets instead of overwriting `config.fish`
- installs common CLI tools with Homebrew when available
- installs the Teleport `tsh` client
- works in GitHub Codespaces and other Debian/Ubuntu-based environments
