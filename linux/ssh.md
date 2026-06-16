---
description: Setup SSH authentication on a Linux server from Linux/Windows
icon: square-terminal
---

# SSH

### Generate SSH Keys

```bash
ssh-keygen
```

### Copy Public Key to Remote Linux Host <a href="#copy-ssh-key-to-remote-linux-device" id="copy-ssh-key-to-remote-linux-device"></a>

#### From Linux:

{% hint style="info" %}
To connect via SSH key, you must put your **Public Key** in the remote server's `~/.ssh/authorized_keys` file (requiring initial access like physical or password ssh). Your **Private Key** is your secret proof of identity and must **never** leave your local machine.
{% endhint %}

<pre class="language-bash"><code class="lang-bash">ssh-copy-id &#x3C;user>@<a data-footnote-ref href="#user-content-fn-1">&#x3C;hostname></a> # -p &#x3C;port-number> (optional)
</code></pre>

OR

```bash
cat ~/.ssh/id_rsa.pub | ssh <user>@<hostname> 'umask 0077; mkdir -p .ssh; cat >> .ssh/authorized_keys && echo "Key copied"'
```

#### From Windows:

```powershell
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh <hostname> "cat >> .ssh/authorized_keys"
```

### (Optional) SSH Config

Create .ssh/config file&#x20;

<pre><code>Host MyServer
  HostName &#x3C;hostname>
  User &#x3C;user>
  IdentityFile <a data-footnote-ref href="#user-content-fn-2">~/.ssh/id_rsa</a>

Host blabla
  HostName &#x3C;hostname>
  User &#x3C;user>
  IdentityFile ~/.ssh/id_rsa_blabla
</code></pre>

You can then connect easily to ssh like this:

```bash
ssh MyServer
```

If you use VSCode, it will also detect your SSH Hosts from config file.

### Port Forwarding & Jump Hosts

Forward a local port to a service reachable from the remote host with `-L`. For example, to reach a VNC port (`5900 + N`) running on a server through SSH — see [Accessing a headless VM over VNC](../networking/kvm-qemu-vde2.md#accessing-a-headless-vm-over-vnc):

```bash
ssh user@server -L 5948:localhost:5948   # local 5948 -> server's 5948
```

You can also make these forwards permanent in `~/.ssh/config`. A jump host (here `bifrost`) lets you reach machines behind it without retyping long addresses or ports:

```
Host bifrost
  HostName 2001:660:5402:2fe:baac:6fff:fe7f:4223
  Port 8163
  LocalForward 7004 thorin:22
  LocalForward 7007 panama7:22
```

Then `ssh user@bifrost` opens the tunnels, and from there you can `ssh thorin` / `ssh panama7`. To reach a machine behind the jump host directly from elsewhere, forward to its address:

```bash
ssh user@bifrost -L 7007:10.30.3.4:22   # 10.30.3.4 = target reachable from bifrost
```

{% hint style="info" %}
You might encounter an issue with VSCode where it'll ask you everytime the Remote Platform, here's how to fix it
{% endhint %}

1. Press F1 and <mark style="color:red;">**open user Settings (JSON)**</mark>
2. Add your remote hosts like this:

```json
"remote.SSH.remotePlatform": {
    "grenx": "linux",
    "ServMaison": "linux"
  }
```

[^1]: IP Address or FQDN (domain name)

[^2]: path to private key
