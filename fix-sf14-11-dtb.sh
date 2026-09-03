#!/bin/bash
# fix-sf14-11-dtb.sh - force correct DTB for Acer Swift SF14-11T (Bluetang_SX1)
# Root cause: boot uses x1p42100-acer-swift-go14-01.dtb (SFG14-01, X1-45, 8-core)
#   instead of x1p64100-acer-swift-sf14-11.dtb (SF14-11, X1-85, 10-core).
# Symptoms fixed: CPU7 fail (-22), GPU GMU timeout (-110/-22), battery EAGAIN unknown 0%,
#   no /sys/class/typec (USB-C dock DP alt-mode), fwupd "System power is too low".
# Kernel 7.0.0-30-generic is correct (contains SF14-11 DTB) - no kernel change needed.
# Requires sudo. Run after setup-passwordless-sudo.sh or with password.
set -euo pipefail

KVER="$(uname -r)"
SRC="/usr/lib/firmware/${KVER}/device-tree/qcom/x1p64100-acer-swift-sf14-11.dtb"
DST_VER="/boot/dtb-${KVER}"
DST_GENERIC="/boot/dtb"

echo "== Acer SF14-11 DTB fix =="
echo "DMI product: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo unknown)"
echo "DMI board:   $(cat /sys/class/dmi/id/board_name 2>/dev/null || echo unknown)"
echo "Current DT model: $(tr '\0' '\n' < /proc/device-tree/model 2>/dev/null | head -n1 || echo unknown)"
echo "Kernel: ${KVER}"
echo "Source DTB: ${SRC}"
echo ""

if [ ! -f "${SRC}" ]; then
  echo "ERROR: correct DTB not found at ${SRC}"
  echo "Check: ls /usr/lib/firmware/${KVER}/device-tree/qcom/*acer*.dtb"
  exit 1
fi

echo "[1/4] Copying correct DTB to /boot (GRUB 10_linux auto-adds devicetree line)..."
sudo cp -v "${SRC}" "${DST_VER}"
sudo cp -v "${SRC}" "${DST_GENERIC}"
# Also keep a named copy for manual GRUB editing if needed
sudo cp -v "${SRC}" "/boot/x1p64100-acer-swift-sf14-11.dtb"
ls -lh "${DST_VER}" "${DST_GENERIC}" /boot/x1p64100-acer-swift-sf14-11.dtb

echo ""
echo "[2/4] Firmware workaround (no Windows to extract from)..."
echo "      SF14-11 needs qcom/x1e80100/ACER/SF14-11/{qcadsp,qccdsp,qcdxkmsuc}8380.mbn"
echo "      linux-firmware only ships Dell/Lenovo 8380 blobs. Same SoC (8380), same audio as T14s,"
echo "      so copy Lenovo 21N1 (ThinkPad T14s) blobs as temporary workaround."
ACER_FW="/lib/firmware/qcom/x1e80100/ACER/SF14-11"
LENOVO_FW="/lib/firmware/qcom/x1e80100/LENOVO/21N1"
if [ -d "${LENOVO_FW}" ]; then
  sudo mkdir -p "${ACER_FW}"
  # Copy only if destination empty/missing to avoid overwriting real future firmware
  if [ -z "$(ls -A "${ACER_FW}" 2>/dev/null)" ]; then
    echo "Copying ${LENOVO_FW} -> ${ACER_FW} ..."
    sudo cp -av "${LENOVO_FW}/." "${ACER_FW}/"
  else
    echo "Destination ${ACER_FW} already has files, skipping copy:"
    ls -lh "${ACER_FW}"
  fi
else
  echo "WARNING: ${LENOVO_FW} not found, skipping firmware copy."
  echo "Install firmware-qcom-dsp or qcom-firmware-extract v20 when available."
fi

echo ""
echo "[3/4] Rebuilding initramfs (includes x1e80100 + x1p42100 per ubuntu-x1e-settings hook)..."
sudo update-initramfs -u -k "${KVER}"

echo ""
echo "[4/4] Updating GRUB..."
sudo update-grub

echo ""
echo "== Verify GRUB entry =="
if sudo grep -q "devicetree.*dtb" /boot/grub/grub.cfg 2>/dev/null; then
  echo "OK: devicetree line present in /boot/grub/grub.cfg:"
  sudo grep "devicetree" /boot/grub/grub.cfg | head -n 10
else
  echo "WARNING: no devicetree line in grub.cfg (need sudo to read?)."
  echo "If missing, GRUB 10_linux did not detect /boot/dtb-${KVER}."
  echo "Manual fallback: add 'devicetree /x1p64100-acer-swift-sf14-11.dtb' after initrd line in GRUB menu (press 'e' at boot)."
fi

echo ""
echo "Done. REBOOT, then verify:"
echo "  cat /proc/device-tree/model  # should be: Acer Swift 14 AI (SF14-11)"
echo "  lscpu | grep -E 'CPU\\(s\\)|On-line'  # should be 10 CPUs, none offline"
echo "  upower -i /org/freedesktop/UPower/devices/battery_qcom-battmgr-bat | grep -E 'state|percentage'"
echo "  ls /sys/class/typec/  # should list ports (was empty)"
echo "  dmesg | grep -i -E 'adreno|gmu|battmgr|ucsi' | head"
echo "  journalctl -k -b | grep -E 'Machine model|psci.*CPU|adreno_load_gpu' | head"
echo ""
echo "Keep charger connected until battery reports correctly (user already does)."
echo "If GPU still fails, install qcom-firmware-extract v20 (resolute has v17, needs v20 from questing):"
echo "  sudo apt update && sudo apt install mesa-utils vulkan-tools"
echo "  # then test with glxinfo -B (should show Adreno X1-85, not llvmpipe)"
