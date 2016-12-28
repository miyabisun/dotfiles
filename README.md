# Overview

my dotfiles and installation scripts.

# Installation

```Bash
curl -L https://raw.github.com/miyabisun/dotfiles/master/install | bash
```

- .editorconfig
- .gitconfig
- .tmux.conf
- .vimrc
- .ssh

# Usage

```Bash
$ ~/.dotfiles/bin/ssh-install
$ cat << EOS > ~/.ssh/conf.d/test.conf
HOST example-server
  HostName example.com
  User user_name
  IdentityFile ~/.ssh/id_rsa
EOS
$ ssh-update
$ cat ~/.ssh/config
HOST example-server
  HostName example.com
  User user_name
  IdentityFile ~/.ssh/id_rsa
```

