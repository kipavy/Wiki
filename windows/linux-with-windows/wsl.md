# WSL

{% tabs %}
{% tab title="Easy way" %}
Open Terminal.

```powershell
wsl --install
```

1. Wait, after install, reboot PC
2. Finally, Open Ubuntu terminal and setup username and password (don't leave it empty)
{% endtab %}

{% tab title="Easy way 2" %}
Open Visual Studio Code.

1. Install the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl). If you plan to work with other remote extensions in VS Code, you may choose to install the [Remote Development extension pack](https://aka.ms/vscode-remote/download/extension)

<figure><img src="../../.gitbook/assets/image (4).png" alt=""><figcaption></figcaption></figure>

<figure><img src="../../.gitbook/assets/image (5).png" alt=""><figcaption></figcaption></figure>

<figure><img src="../../.gitbook/assets/image (6).png" alt=""><figcaption></figcaption></figure>

<figure><img src="../../.gitbook/assets/image (8).png" alt=""><figcaption></figcaption></figure>

2. Wait, after install, reboot PC
3. Finally, Open Ubuntu terminal and setup username and password (don't leave it empty)
{% endtab %}
{% endtabs %}

You can uninstall snap if you dont use it (run inside wsl ubuntu):

```bash
bash <(curl -fsSL https://gitlab.com/scripts94/kubuntu-get-rid-of-snap/-/raw/main/Kubuntu_get_rid_of_Snap.sh)
```

## Useful commands/tools

### WSL Distro Manager

[https://github.com/bostrot/wsl2-distro-manager](https://github.com/bostrot/wsl2-distro-manager)

### List installed distros

<pre class="language-powershell"><code class="lang-powershell">wsl <a data-footnote-ref href="#user-content-fn-1">-l -v</a>
</code></pre>

### Reinstall distro

```powershell
wsl --unregister <distro-name>
wsl --install -d <distro-name>
```

### Install a distro in a specific location

By default distros live in `%LOCALAPPDATA%`, on `C:`. To put it elsewhere:

```powershell
wsl --install -d <distro-name> --location D:\WSL\<distro-name>
```

### Move an existing distro

```powershell
wsl --shutdown
wsl --manage <distro-name> --move D:\WSL\<distro-name>
```

### Find where a distro (and its ext4.vhdx) is stored

```powershell
Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss | Get-ItemProperty | Select-Object DistributionName, BasePath
```

***

### WSL takes too much space ?

{% hint style="info" %}
If you notice your WSL2 is taking too much space even after some clean, here's how you can compact your WSL2 virtual disk on windows (If you're having trouble with automatic, just doit manually)
{% endhint %}

The vhdx still never shrinks on its own ([issue](https://github.com/microsoft/WSL/issues/4699) still open), but since WSL 3.0.1 there is a built-in compact command (`wsl --update` first):

```powershell
wsl -d <distro-name> -u root fstrim -av
wsl --shutdown
wsl --manage <distro-name> --compact
```

On older WSL versions, use [wslcompact](https://github.com/okibcn/wslcompact?tab=readme-ov-file#option-1-as-a-powershell-module). If wslcompact did nothing, you can try the following script to compact vdisk:

{% tabs %}
{% tab title="Automatic" %}
```powershell
Invoke-WebRequest -Uri "https://gist.githubusercontent.com/kipavy/fb858118c2b373369741ac084c6c3d45/raw/7598671681ec3513d9c27931d9730f57639f1436/compact-wsl2.ps1" -OutFile "$env:TEMP\compact-wsl2.ps1"; powershell -ExecutionPolicy Bypass -File "$env:TEMP\compact-wsl2.ps1"
```
{% endtab %}

{% tab title="Manual" %}
```powershell
# open admin powershell
Optimize-VHD -Path ./ext4.vhdx -Mode Full
```

Or

```powershell
#locate ext4.vhdx file with everything or windirstat. copy path
#open powershell
wsl --shutdown
diskpart
DISKPART> select vdisk file="<path to .vhdx>"
DISKPART> compact vdisk
```
{% endtab %}
{% endtabs %}

[^1]: \--list --verbose
