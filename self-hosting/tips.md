# Tips

### Get your Public IP (external) from terminal:

```bash
curl https://ipinfo.io/ip
```

### Add a swap file (OOM cushion for a container host)

A box running lots of containers with **no swap** has no safety net: if RAM spikes,
the kernel's OOM-killer picks a victim (maybe your database). A modest swap file lets
a spike degrade gracefully instead. Note: swap is *not* a substitute for RAM, and on
a DB host you want a **low `swappiness`** so hot pages aren't paged out (no thrashing).

```bash
# 8 GB swapfile (use dd instead of fallocate on btrfs/zfs to avoid "holes")
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Persist across reboots
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# DB-friendly: prefer dropping cache over swapping out active pages
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl -w vm.swappiness=10
```

Verify: `free -h` and `swapon --show`. To remove it: `sudo swapoff /swapfile &&
sudo rm /swapfile`, then delete the `fstab` line and the `sysctl.d` file.

> Swap protects against **out-of-memory kills**, not data loss — don't confuse it
> with backups or a managed provider's durability.
