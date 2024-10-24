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









[^1]: IP or FQDN
