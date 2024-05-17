# Github SSH Access for private repo

<pre class="language-bash"><code class="lang-bash"><strong>ssh-keygen -t ed25519 -C "your_email@example.com"
</strong><strong>cat ~/.ssh/id_ed25519.pub
</strong></code></pre>

Copy content and paste in deploy key Go to repo>settings>deploy key

<pre class="language-bash"><code class="lang-bash"><strong>git clone git@github.com:username/repo.git
</strong></code></pre>
