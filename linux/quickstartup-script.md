# QuickStartup Script



```bash
#!/usr/bin/env bash

print_recommendations() {
    echo "Recommended GNOME Shell Extensions:"
    echo "- Clipboard indicator"
    echo "- Tiling Assistant"
    echo "- Add to Desktop"
    echo "- Burn My Window"
    echo "- Compiz alike magic lamp effect"
    echo "- Compiz window effect"
    echo "- RunCat"
}

# Dark Theme + % Battery
gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
gsettings set org.gnome.desktop.interface show-battery-percentage true

# Small Centered Dock + Hide Unmounted Volumes
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position \'BOTTOM\'
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts-only-mounted true

# Fish Shell Install
sudo apt-add-repository ppa:fish-shell/release-3
sudo apt update && sudo apt upgrade
sudo apt install fish
sudo chsh -s /usr/bin/fish

# Gnome Extensions Install
sudo apt install gnome-shell-extension-manager 
print_recommendations


# Snap Purge + Install New App Store w/ flatpak
sudo snap remove $(snap list | awk '!/^Name|^core/ {print $1}')
sudo apt remove --purge -y snapd gnome-software-plugin-snap
rm -rf ~/snapd
rm -rf ~/snap
sudo rm -rf /snap
sudo rm -rf /var/snap
sudo rm -rf /var/lib/snapd

cat <<EOF >> /etc/apt/preferences.d/nosnap.pref
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

sudo apt update
sudo apt install --install-suggests gnome-software
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo


#install chromium, bitwarden, dark reader

# INSTALL VSCODE
wget -O vscode "https://go.microsoft.com/fwlink/?LinkID=760868"
sudo dpkg -i vscode

#GET THE APP MINIMIZED WHEN CLICKING ON THEM
#gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'

#PURGE SNAP AND REPLACE WITH FLATPAK
#delete all the listed snap apps
#snap list
#sudo snap remove --purge firefox
#sudo snap remove --purge snap-store
#sudo snap remove --purge gnome-3-38-2004
#sudo snap remove --purge gtk-common-themes
#sudo snap remove --purge snapd-desktop-integration
#sudo snap remove --purge bare
#sudo snap remove --purge core20
#sudo snap remove --purge snapd
#sudo apt purge snapd
```
