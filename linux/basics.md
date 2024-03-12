# Basics

### Write in a file w/ a single command:

#### single line:

```
echo "hello world" > file  # This override the content
echo "hello world 2" >> file  # This concatenate
```

#### Multiple lines:

{% code fullWidth="false" %}
```bash
cat <<EOF >file
bla bla
...
bla bla
EOF
```
{% endcode %}

### Create Desktop shortcut

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

