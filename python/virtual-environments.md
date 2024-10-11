# Virtual Environments

A Python virtual environment (venv) is an isolated environment that allows you to manage dependencies for different projects separately. This isolation helps avoid conflicts between packages and ensures that each project has access to the specific versions of libraries it needs.

<figure><img src="../.gitbook/assets/image.png" alt="" width="563"><figcaption></figcaption></figure>

<details>

<summary>Using venv</summary>

**Creating and activating an environment** You can do this by running the following on a terminal [https://doc.qt.io/qtforpython-6/quickstart.html#quick-start:](https://doc.qt.io/qtforpython-6/quickstart.html#quick-start:)

* Create environment (Your Python executable might be called `python3`):

<pre class="language-bash"><code class="lang-bash"><a data-footnote-ref href="#user-content-fn-1">python</a> -m venv myenv
</code></pre>

* Activate the environment (Linux and macOS):

```bash
source myenv/bin/activate
```

* Activate the environment (Windows):

```powershell
myenv\Scripts\activate.bat
```

</details>

<details>

<summary>Using conda</summary>

1. Install miniconda for example (conda init if not already)
2. Create env:

<pre class="language-bash"><code class="lang-bash"><strong>conda create <a data-footnote-ref href="#user-content-fn-2">--prefix FULL_PATH_ENV</a> <a data-footnote-ref href="#user-content-fn-3">python=3.12</a>
</strong></code></pre>

* Activate venv:

<pre class="language-bash"><code class="lang-bash">conda activate <a data-footnote-ref href="#user-content-fn-4">FULL_PATH_ENV</a>
</code></pre>

</details>



[^1]: Your Python executable might be called `python3`

[^2]: you can replace this by myenv if you want to create in current dir

[^3]: you can ommit this, it'll use latest python

[^4]: 
