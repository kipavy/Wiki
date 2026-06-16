---
description: >-
  Create and run Debian VMs with KVM/QEMU, wire them together with VDE2 virtual
  switches, expose them over VNC, and edit their disk images offline.
---

# Virtual Networking with KVM/QEMU & VDE2

This page shows how to build VMs from scratch and connect them through **VDE2** (Virtual Distributed Ethernet) virtual switches. This is the foundation for the [Linux router](linux-router.md) and server labs.

## Creating and running a VM

Create a virtual disk (qcow2 grows on demand up to the given size):

```bash
qemu-img create -f qcow2 debian.qcow2 4G
```

Install Debian into it from an ISO:

```bash
kvm -m 1G -hda debian.qcow2 -cdrom debian.iso
```

Boot the installed VM:

```bash
kvm -m 1G -hda debian.qcow2
```

{% hint style="info" %}
`kvm` is just `qemu-system-x86_64 -enable-kvm`. `-m` sets RAM, `-hda` the disk.
{% endhint %}

### Cloning

A VM is just its disk file, so cloning is a copy:

```bash
cp debian.qcow2 debian-clone.qcow2
```

{% hint style="warning" %}
Never boot two VMs from the **same** disk file at once — they'll corrupt it. Clone first.
{% endhint %}

## Connecting VMs with VDE2

A VDE switch is exposed as a control socket (e.g. `/var/run/vde2/myswitch.ctl`). Attach a VM to it by pairing a virtual NIC with a `vde` backend:

```bash
kvm -m 1G -hda debian-clone.qcow2 \
  -net nic,macaddr=42:30:03:01:01:02 \
  -net vde,sock=/var/run/vde2/myswitch.ctl
```

* Give every NIC a **unique MAC address** — duplicate MACs on the same switch break connectivity.
* A VM can have several NICs on different switches; just repeat the `-net nic`/`-net vde` pair. This is exactly how a [router](linux-router.md) straddles two networks:

```bash
kvm -m 4G -hda router.qcow2 \
  -net nic,macaddr=42:48:04:03:02:01 -net vde,sock=/var/run/vde2/lan.ctl \
  -net nic,macaddr=42:48:04:03:02:02 -net vde,sock=/var/run/vde2/priv.ctl
```

## Accessing a headless VM over VNC

Add `-vnc :N` to expose the display on TCP port `5900 + N`:

```bash
kvm -m 2G -hda server.qcow2 -nographic -vnc :48   # listens on 5948
```

Connect from another machine with any VNC client (e.g. `vinagre host:48`). If the VNC port isn't directly reachable, tunnel it over SSH first — see [Port Forwarding & Jump Hosts](../linux/ssh.md#port-forwarding-and-jump-hosts).

## Editing a VM's disk image offline (kpartx)

You can mount a VM's filesystem on the host to add, edit or recover files without booting it. `kpartx` works on **raw** images, so convert first:

```bash
qemu-img convert -O raw server.qcow2 server.raw
```

Map the image's partitions to loop devices and mount the one you need:

```bash
sudo kpartx -av server.raw          # creates /dev/mapper/loop0p1, loop0p2, ...
sudo mount /dev/mapper/loop0p1 /mnt
```

Make your changes, then unmount and unmap cleanly:

```bash
sudo touch /mnt/home/user/hello.txt
sudo umount /mnt
sudo kpartx -d server.raw
```

Convert back to qcow2 if needed:

```bash
qemu-img convert -O qcow2 server.raw server-edited.qcow2
```
