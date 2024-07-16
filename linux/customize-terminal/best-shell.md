# Best Shell

Bash is the most common shell and is for most people more than enough but if you want a more modern shell with autocompletion and others useful feature, you can change your shell.

There are 2 really good shell other than bash, [Zsh ](https://ohmyz.sh/)and [Fish](https://fishshell.com/).

* Fish comes with really great default right out of the box, its a really good option for beginners but also for more advanced users though it's not POSIX compliant, that means you can't run bash directly in the terminal. That is the reason I don't recommend it if you're scripting bash. Although you can still use it along with bash but I dont like to switch between 2 shells. Here is how to install latest Fish on Debian based distros:

```bash
sudo apt-add-repository ppa:fish-shell/release-3
sudo apt-get update && sudo apt-get upgrade
sudo apt-get install fish
chsh -s /bin/bash $USER # Optionnal, sets default shell to fish
```

* Zsh is really customizable and is POSIX compliant, it means like bash it can run bash,sh scripts directly in the terminal. If you're willing to get the best terminal, I think its the best of both world. Here is a [script install](https://github.com/romkatv/zsh4humans) that I recommand:

```bash
if command -v curl >/dev/null 2>&1; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
else
  sh -c "$(wget -O- https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install)"
fi
```

***

After installing zsh, if you want to change prompt (for e.g mine below) you can by following these steps:

<figure><img src="../../.gitbook/assets/image (13).png" alt=""><figcaption><p>Custom Prompt</p></figcaption></figure>

1. Open <mark style="color:red;">`~/.p10k.zsh`</mark> in a text editor
2. Seek for the line with <mark style="color:red;">`POWERLEVEL9K_LEFT_PROMPT_ELEMENTS`</mark>&#x20;
3. You can then add whatever element you want to the list, it will show on the left side of the prompt in the order you specified, here is a list of elements for reference: [https://github.com/Powerlevel9k/powerlevel9k/blob/master/README.md#available-prompt-segments](https://github.com/Powerlevel9k/powerlevel9k/blob/master/README.md#available-prompt-segments)

You can also change font-family: [https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation](https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation)&#x20;

