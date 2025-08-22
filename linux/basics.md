# Basics

### Write in a file w/ a single command:

#### single line:

```
echo "hello world" > file  # “create/overwrite” operation
echo "hello world 2" >> file  # concatenate (append)
```

#### Multiple lines:

create/overwrite

{% code fullWidth="false" %}
```bash
cat > file <<EOF
bla bla
...
bla bla
EOF
```
{% endcode %}

concatenate (append)

```bash
cat >> file <<EOF
bla bla
...
bla bla
EOF
```

### Create Desktop shortcut

#### For Scripts/Programs:

```bash
cat <<EOF >~/Desktop/my_shortcut.desktop
[Desktop Entry]
Type=Application
Name=nom du programme
GenericName=nom générique
Comment=commentaire/description du programme
Icon=icône du programme #il peut s'agir d'un chemin, ou alors du nom d'une icône contenue dans votre thème d'icônes
Exec=commande qui permettrait d'ouvrir le programme par le terminal
Terminal=false  #ouvrir ou non un terminal lors de l'exécution du programme (false ou true)
StartupNotify=false  #notification de démarrage ou non (false ou true)
Categories=catégories du programme  #Exemple: Categories=Application;Game;ArcadeGame;
EOF
```

You can also look at existing shortcuts by doing: <mark style="color:red;">`ls -l /usr/share/applications/`</mark>

User specific shortcuts for app menu are in <mark style="color:red;">`~/.local/share/applications`</mark>

#### For file/folder shortcut:

<pre class="language-bash"><code class="lang-bash">ln -s original.txt ~/<a data-footnote-ref href="#user-content-fn-1">Desktop</a>/shortcut.txt
</code></pre>

### Scheduling tasks

#### (Option 1) Create a service with auto execution at startup:

<pre class="language-bash"><code class="lang-bash">sudo sh -c 'cat &#x3C;&#x3C;EOF >/etc/systemd/system/my_service.service
[Unit]
Description=My Script

[Service]
ExecStart=/home/test/my_script.sh

[Install]
WantedBy=multi-user.target
EOF'

<a data-footnote-ref href="#user-content-fn-2">sudo systemctl enable --now my_service</a> # Enables the service at startup and start it now
</code></pre>

#### (Option 2): Schedule tasks with crontab:

Crontab is more versatile, you can schedule very minute, hour, at reboot, whatever you want, see [https://crontab.guru/](https://crontab.guru/) for help.

Here are the 2 most usedul crontab commands:

```bash
crontab -l  # List Current cron jobs
crontab -e  # Edit jobs
```

Here is 2 ways of scheduling tasks at reboot, if your task is complex, prefer shell script:

```antlr4
@reboot [path to command] [argument1] [argument2] … [argument n]
@reboot [part to shell script]
```

### Zip & Unzip Using tar

#### Zip

```bash
tar -czvf path/to/target.tar.gz path/to/dir
```

#### Unzip

```bash
tar -xvf path/to/archive.tar.gz
```

[^1]: can change depending on OS language

[^2]: Same as:

    <mark style="color:red;">`systemctl enable my_service`</mark>

    <mark style="color:red;">`systemctl start my_service`</mark>
