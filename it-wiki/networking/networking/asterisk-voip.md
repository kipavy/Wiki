---
description: >-
  Run an Asterisk softswitch and bridge a Bluetooth smartphone to it, so an
  incoming call to the phone is answered by a custom Asterisk dialplan.
---

# Asterisk VoIP

[Asterisk](https://www.asterisk.org/) is an open-source PBX / softswitch. This lab connects a smartphone to Asterisk over **Bluetooth** (`chan_mobile`), so when someone calls the phone, Asterisk answers and plays a custom message — here, a greeting tapped out in **Morse code**.

## Install

```bash
sudo apt install asterisk asterisk-mobile
```

## Find the Bluetooth controller

Get the local adapter's ID (usually `hci0`) and MAC:

```bash
hcitool dev
```

## Pair the phone

```bash
bluetoothctl
```

Then, inside the prompt:

```
show              # display controller state
discoverable yes
pair <PHONE_MAC>
connect <PHONE_MAC>
```

## Configuration

{% hint style="warning" %}
Load the `chan_mobile` module **before** connecting the smartphone. If you connect first, the module fails to load and you have to disconnect the phone and reboot.
{% endhint %}

### `/etc/asterisk/modules.conf`

```ini
[modules]
autoload=yes

load => res_musiconhold.so
load => chan_console.so
load => chan_mobile.so
load => chan_alsa.so

noload => pbx_gtkconsole.so
noload => pbx_kdeconsole.so
noload => chan_oss.so
noload => cdr_sqlite.so
noload => res_config_odbc.so
noload => res_config_pgsql.so
```

### `/etc/asterisk/chan_mobile.conf`

```ini
[adapter]
id=hci0
address=DC:A6:32:F3:88:DD    ; the controller MAC from hcitool dev
context=incoming-mobile

[xiaomi]
address=70:5F:A3:C3:8B:20    ; the phone MAC
port=3
context=incoming-mobile
adapter=hci0
```

### `/etc/asterisk/extensions.conf`

```ini
[default]
; place outgoing calls through the mobile
exten => _0.,1,Dial(Mobile/xiaomi/${EXTEN},42)

[incoming-mobile]
exten => s,1,Answer()
; exten => s,2,Playback(tt-monkeys)   ; play a built-in sound instead
exten => s,2,MorseCode(hello there)
```

`[incoming-mobile]` runs whenever a call comes in over the Bluetooth link. Add more priorities to build a fuller voicemail/menu.

{% hint style="info" %}
Custom `.gsm` sounds go in `/usr/share/asterisk/sounds/en`.
{% endhint %}

### `/etc/asterisk/sip.conf`

```ini
[telephone]
type=friend
context=Bluetooth
```

## Bring it up

```bash
sudo systemctl restart asterisk
sudo asterisk -rvvvvvvv          # attach to the Asterisk CLI
```

In the CLI, confirm the mobile channel driver is loaded:

```
module load chan_mobile.so
```

If that errors, disconnect the phone and reboot (load the module first, then pair/connect). Once it's up, call the connected phone — Asterisk answers and plays your dialplan.
