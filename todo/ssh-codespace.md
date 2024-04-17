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
