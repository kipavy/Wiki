# Useful Commands

#### Change default shell:

```bash
chsh -s /bin/bash $USER
```

#### Restart shell (for bash, zsh, may not work with fish, csh, sh...)

<pre><code>exec "$SHELL" <a data-footnote-ref href="#user-content-fn-1">-l</a>
</code></pre>

#### **Create GIF with your screen view:**

```bash
sudo apt install -y peek && peek
```

#### [pac: Apt-like pacman aliases for pacman](https://github.com/bbedward/pac-pacman-aliases)

This is really useful for Arch-based distros if you're not familiar with pacman syntax

```bash
paru -S --noconfirm pac-pacman-aliases
```

You can also configure an alias to make it a synonym for apt:

```bash
# FOR FISH
echo '
alias -s apt 'pac'
' >> ~/.config/fish/config.fish
echo '
function sudo
    if functions -q $argv[1]
        set cmd "command sudo fish -c \"$argv\""
        eval $cmd
    else
        command sudo $argv
    end
end
' > ~/.config/fish/functions/sudo.fish
```

```bash
# FOR ZSH
cat >> ~/.zshrc <<EOF
alias apt='pac'
alias sudo='sudo '
EOF
```

```bash
# FOR BASH
cat >> ~/.bashrc <<EOF
alias apt='pac'
alias sudo='sudo '
EOF
```

#### **fuck :** [_**The Fuck**_](https://github.com/nvbn/thefuck) **is a magnificent app that corrects errors in previous console commands. Install script:**

```bash
#!/usr/bin/env bash
sudo apt update
sudo apt install python3-dev python3-pip python3-setuptools python3-venv
python3 -m venv ~/.config/thefuck
source ~/.config/thefuck/bin/activate
pip install setuptools
pip install git+https://github.com/nvbn/thefuck.git
echo 'export PATH="$HOME/.config/thefuck/bin:$PATH"' >> ~/.bashrc
fuck
fuck
```

#### Remove unused packages

```bash
sudo apt autoremove
```

#### Clear shell history

```shellscript
history -c && history -w
```

and for powershell:

```powershell
Clear-History
Remove-Item (Get-PSReadLineOption).HistorySavePath -ErrorAction SilentlyContinue
```

[^1]: login shell: it will reload \~/.bashrc ...
