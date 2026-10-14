---
description: How to connect to a SSH Server using a Github Codespace as a Proxy (JumpHost)
---

# SSH Codespace

## In Codespace

### Creating new sudo user

<pre class="language-bash"><code class="lang-bash">sudo adduser <a data-footnote-ref href="#user-content-fn-1">user</a> # dont leave password blank
</code></pre>

```bash
sudo usermod -aG sudo user # add user sudo permissions
```

```bash
sudo visudo
```

Find these lines and add permissions for new user:

```bash
User privilege specification
root ALL=(ALL:ALL) ALL
user ALL=(ALL:ALL) ALL
```

save ctrl+x ; y ; enter

### Editing ssh config

replace port by any port you want for example 8282

```bash
sudo nano /etc/ssh/sshd_config
```

```bash
sudo service ssh start
```

```bash
ssh -R 6363:localhost:8282 serveo.net # any source port for example 6363
```

## Local Computer

### Connection test

```bash
ssh user@serveo.net -p 6363
```

### SSH Config

After that, host will appear in vscode remote tab.\
F1>ssh config (open config file)

<pre class="language-yang"><code class="lang-yang"><a data-footnote-ref href="#user-content-fn-2">Host codespace</a>
  HostName serveo.net
  User user
  Port 6363

Host studies
  HostName YOUR_SERVER_IP
  User ubuntu
  IdentityFile ~/.ssh/studies.key
  ProxyJump codespace
</code></pre>

Now you can directly connect through remote connection menu in vscode, thanks to this you can benefit of all vscode feature set, extensions on your server without connecting directly to it.

[^1]: user name can be whatever you want

[^2]: This block is the first host you connect to, it's the proxy you will use to connect to your server
