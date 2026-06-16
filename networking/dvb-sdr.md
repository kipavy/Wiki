---
description: >-
  Scan, watch and dissect over-the-air DVB-T television, inspect the transport
  stream with dvbsnoop, visualize the spectrum with an RTL-SDR, and re-stream
  channels over multicast.
---

# DVB & SDR — Broadcast TV Analysis

Working with a DVB-T tuner (and optionally an RTL-SDR dongle) to receive, analyze and re-distribute digital terrestrial television.

## Setup

Check the adapter is detected:

```bash
ls /dev/dvb
```

Install the tools:

```bash
apt install w-scan dvb-apps
```

## Scanning for channels

```bash
time w_scan -X -ft > channels.conf 2> channels.log
```

`channels.conf` then holds the channel list. You can cross-reference the multiplexes (in France, R1–R7) with the broadcaster coverage maps. Rule of thumb for the carrier frequency:

```
frequency (MHz) = channel × 8 + 306
```

## Tuning and signal quality

Tune to a channel by name:

```bash
tzap -c channels.conf "Arte"
```

A healthy lock looks like:

```
status 1f | signal 0000 | snr 0142 | ber 00000000 | unc 00000000 | FE_HAS_LOCK
```

A **BER (bit error rate) of 0** means a clean signal.

## Dissecting the transport stream with dvbsnoop

```bash
apt install dvbsnoop
```

List the PIDs being received:

```bash
sudo dvbsnoop -pd 4 -s pidscan >> analyse
```

Look for ITU-T references (the ITU-T sets the telecom standards for these audiovisual systems):

```bash
grep ITU-T analyse
```

Inspect a specific stream by PID (e.g. the MPEG video PID `0x0140`):

```bash
dvbsnoop 0x0140
```

Count the audio languages carried in a stream's PMT:

```bash
dvbsnoop 300 -n 1 | grep lang   # 300 = decimal PID of the PMT, -n 1 = one pass
```

### Programmes and EPG

```bash
dvbsnoop -n 1 -pd 4 0      # list programmes (PAT)
dvbsnoop -n 4 -pd 4 17     # SDT — service names / service IDs
dvbsnoop -n 4 -pd 4 18     # EIT — upcoming programmes (match by service ID)
```

Measure a PID's bitrate (min/max). Typically the TOT (PID 20) is the lowest and the video streams the highest:

```bash
dvbsnoop -s bandwidth -n 1000 -pd 2 PID
```

## Spectrum visualization with an RTL-SDR

```bash
apt install rtl-sdr
```

Sweep a frequency range and plot it as a heatmap:

```bash
rtl_power -f 470M:640M:10k b.csv   # 470–640 MHz, 10 kHz resolution
heatmap.py b.csv b.png
display b.png
```

## Re-streaming TV over multicast (mumudvb)

**On the source machine** (with the tuner):

```bash
pgrep -la mumudvb     # check it isn't already running; kill <PID> if so
```

Create `mumu0.conf`:

```ini
autoconfiguration=full
sap=1
card=0
freq=THE_MULTIPLEX_FREQUENCY_IN_KHZ
```

Start sharing the whole multiplex over multicast:

```bash
mumudvb -d -c mumu0.conf
```

**On a client machine:**

1. Run a graphical VM (or desktop).
2. Install and start `pimd` so multicast is routed to the client.
3. Open VLC → **View → Playlist → Network → Network streams (SAP)**.
4. The announced channels appear in the list, ready to play.
