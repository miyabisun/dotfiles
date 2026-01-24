# Overview

This repository manages my dotfiles.
Instead of copying files directly, the installation script creates symbolic links from this repository to your home directory. This keeps your configuration files organized in one place and easy to update.

# Installation

To install the dotfiles, run the following command. This will clone the repository and execute the `bin/install` script.

```bash
curl -L https://raw.github.com/miyabisun/dotfiles/master/install | bash
```

## What the installer does

The `bin/install` script sets up symbolic links for the following configuration files and directories:

### Root Directory
- `~/.editorconfig` -> `.editorconfig`
- `~/.tmux.conf` -> `.tmux.conf`

### SSH Directory
- `~/.ssh/config` -> `ssh/config`
- Creates `~/.ssh/conf.d` directory

### Config Directory (`~/.config`)
- `~/.config/git` -> `config/git`
- `~/.config/nvim` -> `config/nvim`
- `~/.config/tmux` -> `config/tmux`

# Utilities

This repository includes several utility scripts in the `bin/` directory to help manage specific configurations.

## Bitwarden Integration

These scripts integrate with Bitwarden CLI (`bw`) to manage secrets and SSH keys.

### Secrets Management
- **`bin/update-secrets`**: Fetches secrets from Bitwarden "CLI" folder and saves them to `~/.config/.secrets`.
- **`bin/create-secret <key> <value>`**: Creates a new secret in Bitwarden "CLI" folder and updates local secrets.

### SSH Key Management
- **`bin/list-ssh-key`**: Lists available SSH keys in Bitwarden "SSH Keys" folder.
- **`bin/save-ssh-key [name] [filename]`**: Saves a local SSH key to Bitwarden "SSH Keys" folder.
  - Defaults: `name`="default", `filename`="id_rsa".
- **`bin/load-ssh-key [name] [filename]`**: Loads an SSH key from Bitwarden to `~/.ssh/`.

### SSH Config Management
- **`bin/save-ssh-config`**: Interactively selects an SSH config file from `~/.ssh/conf.d/` and saves it to Bitwarden "SSH Config" folder.
- **`bin/load-ssh-configs`**: Restores all SSH configs from Bitwarden to `~/.ssh/conf.d/`.

## Other Scripts

- **`bin/tmux-install`**: Setup script for Tmux.

