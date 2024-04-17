# SSH Codespace

SSH DIRECT TO CODESPACE WITHOUT GITHUB CLI

IN CODESPACE

sudo adduser user (dont leave password blank) sudo usermod -aG sudo user

sudo visudo

## User privilege specification

root ALL=(ALL:ALL) ALL user ALL=(ALL:ALL) ALL

save ctrl+x ; y ; enter

sudo nano /etc/ssh/sshd\_config replace port by any port for example 8282

sudo service ssh start

ssh -R XXXX:localhost:8282 serveo.net (XXXX= any port for example 6363)

now from local computer ssh user@serveo.net -p 6363



to open vscode window to that host passing through jumhost:\
F1>ssh config (open config file)

<pre class="language-yang"><code class="lang-yang"><a data-footnote-ref href="#user-content-fn-1">Host codespace</a>
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

[^1]: This block is the first host you connect to, it's the proxy you will use to connect to your server
