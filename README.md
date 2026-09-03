# acer-sf14-11-linux

Provisioning for **Acer Swift 14 AI SF14-11T** (`Bluetang_SX1`, Snapdragon X Plus
X1P64100) on Ubuntu 26.04 (`7.0.0-30-generic`). Tested on this machine; aimed to
also work on Debian flavors (see caveats).

## What was wrong out of the box

- Boot used `x1p42100-acer-swift-go14-01.dtb` (Go 14, X1-45) instead of
  `x1p64100-acer-swift-sf14-11.dtb` (X1-85) → CPU7 fail, GPU GMU timeout,
  battery `unknown 0%`, empty `/sys/class/typec`.
- DSP firmware (`qcadsp/qccdsp/adsp_dtbs`, `battmgr`) missing from
  linux-firmware for Acer → ADSP offline → `qcom_battmgr EAGAIN`.
- Audio topology `X1E80100-ACER-SWIFT-14-tplg.bin` missing → `snd-x1e80100 -2`.
- UCM 1.2.15.3 has no SF14-11 match (DMI `SX1-Swift 14 AI-Bluetang_SX1`).
- PipeWire defaulted to HDMI (no monitor) → silent YouTube.

## Files here

- `fix-sf14-11-dtb.sh` — GRUB DTB override (`/boot/dtb-<kver>`), Lenovo-blob
  workaround for first boot, `update-initramfs`, `update-grub`. Run with sudo.
- `key-capture.html` — Fn-row scancode capture helper (open in Firefox).
- `ucm/acer-sf14-11.conf.snippet` — UCM block reusing T14s (see below).

## Firmware (NOT committed — Acer license, ~150 MB)

From Acer Support (Windows ARM64): `ADSP_Qualcomm_2.0.7800.0002`,
`Base Driver_Qualcomm_0.7000.1` → install 9 files to
`/lib/firmware/updates/qcom/x1e80100/ACER/SF14-11/` (mode 0644):
`adsp_dtbs.elf` (72K genuine, Lenovo 7.5K fails `-22`), `qcadsp8380.mbn`,
`adspr/jsn adsps/jsn adspua/jsn battmgr/jsn`, `qccdsp8380.mbn`,
`cdsp_dtbs.elf`, `cdspr.jsn`, plus `qcdxkmsuc8380.mbn.zst`.
Then `update-initramfs -u`. (`qcom-firmware-extract -d <FileRepository>`
does the same thing when a Windows partition exists.)

Audio topology (same-HW T14s reuse):
`X1E80100-LENOVO-Thinkpad-T14s-tplg.bin.zst` →
`/lib/firmware/updates/qcom/x1e80100/X1E80100-ACER-SWIFT-14-tplg.bin.zst`.

## Post-install order

1. Install Ubuntu, tick additional drivers (`hwe-qcom-x1e-meta`).
2. Keep Acer driver zips on USB. Run `sudo ./fix-sf14-11-dtb.sh`, reboot.
3. Install genuine DSP files above, `update-initramfs -u`,
   `echo start > /sys/class/remoteproc/remoteproc0/state` (or reboot).
4. Add tplg above, rebind `sound`, append `ucm/` snippet to
   `.../Qualcomm/x1e80100/x1e80100.conf`, restart WirePlumber,
   `wpctl set-default <Speaker>`.
5. Verify: `cat /proc/device-tree/model`, 10 CPUs online,
   `upower` ~100% charging, `ls /sys/class/typec`, `aplay -l`.

## Debian-flavor caveats

Mostly yes: same GRUB `10_linux` DTB mechanism, same `/lib/firmware`
layout, same UCM paths. Differences: Debian kernels may lack the
`x1p64100-acer-swift-sf14-11.dtb` (check
`/usr/lib/firmware/*/device-tree/qcom/`), firmware metapackages are named
differently (`firmware-qcom-*` vs `linux-firmware-qualcomm-*`), no
`hwe-qcom-x1e-meta`/`ubuntu-x1e-settings` (recreate cmdline
`clk_ignore_unused pd_ignore_unused cma=128M efi=noruntime` manually), and
`qcom-firmware-extract` availability varies. Re-test `adsp: running` and
`aplay -l` per distro release.
