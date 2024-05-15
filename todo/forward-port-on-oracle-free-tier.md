# Forward Port on Oracle Free Tier

Ouvrir le port dans l’interface Oracle>VNIC>Security List

<figure><img src="../.gitbook/assets/Untitled.png" alt=""><figcaption></figcaption></figure>

```bash
sudo apt purge ufw
sudo apt-get install firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

sudo firewall-cmd --zone=public --add-port=32400/tcp --permanent
sudo firewall-cmd --reload

sudo iptables -A INPUT -m state --state NEW -p tcp --dport 32400 -j ACCEPT
sudo netfilter-persistent save
```
