---
description: Setup SSH authentication on a Linux server from Linux/Windows
icon: square-terminal
---

# SSH

### Generate SSH Keys

```bash
ssh-keygen
```

### Copy SSH Key to Remote Linux Device <a href="#copy-ssh-key-to-remote-linux-device" id="copy-ssh-key-to-remote-linux-device"></a>

#### From Linux:

<pre class="language-bash"><code class="lang-bash">ssh-copy-id &#x3C;user>@<a data-footnote-ref href="#user-content-fn-1">&#x3C;hostname></a> # -p &#x3C;port-number> (optional)
</code></pre>

OR

```bash
cat ~/.ssh/id_rsa.pub | ssh <user>@<hostname> 'umask 0077; mkdir -p .ssh; cat >> .ssh/authorized_keys && echo "Key copied"'
```

#### From Windows:

```powershell
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh {IP-ADDRESS-OR-FQDN} "cat >> .ssh/authorized_keys"
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





[^1]: IP or FQDN

[^2]: path to private key
