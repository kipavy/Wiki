# SSH Keys & PAT

#### PAT (Personnal Access Token)

In your account settings, you can generate a PAT and then use it like so:

```bash
https://<username>:<PAT>@github.com/username/repo.git
```

#### SSH Keys

<pre class="language-bash"><code class="lang-bash"><strong>ssh-keygen -t ed25519  # PUT A PASSPHRASE OR IT WONT WORK
</strong><strong>cat ~/.ssh/id_ed25519.pub  # KEEP DEFAULT NAME OR IT WONT WORK
</strong></code></pre>

Copy content and paste in deploy key Go to repo>settings>deploy key

<pre class="language-bash"><code class="lang-bash"><strong>git clone git@github.com:username/repo.git
</strong></code></pre>

{% hint style="info" %}
Alternatively, If you go on your account settings, you can also enable global access for your account or for just some repos
{% endhint %}

If you're still having issue to connect, check your permissions with <mark style="color:red;">`ls -la`</mark>

* <mark style="color:purple;">.ssh/</mark> directory: <mark style="color:green;">700</mark> ( <mark style="color:green;">drwx------</mark> )
* <mark style="color:purple;">public key</mark> (.pub file): <mark style="color:green;">644</mark> ( <mark style="color:green;">-rw-r--r--</mark> )
* <mark style="color:purple;">private key</mark> (id\_rsa): <mark style="color:green;">600</mark> ( <mark style="color:green;">-rw-------</mark> )
