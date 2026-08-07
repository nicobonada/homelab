#!/usr/bin/env bash
# Run as root on PVE (web shell or root SSH).
# Moves /mnt/backup from SanDisk Extreme → wiped Samsung T7 Shield.
# Does NOT copy old dumps (treated as untrusted). Creates empty dump/.
#
# Prerequisites:
#   - VM 100 fully stopped (qm shutdown/stop) so virtiofsd releases /mnt/backup
#     and no residual scsi passthrough holds the T7 open.
#   - Guest no longer needs /mnt/backup-drive (passthrough removed from config).
#
# Safe to re-run only if T7 is free and SanDisk still holds /mnt/backup —
# review lsblk before Enter.

set -euo pipefail

# Root shells / restricted PATHs often omit sbin (qm, wipefs, mkfs, sgdisk live there).
# parted is not installed on this PVE host — use sgdisk (gdisk package) instead.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

T7_DISK='/dev/disk/by-id/usb-Samsung_PSSD_T7_Shield_S6SLNS0W103860P-0:0'
T7_PART="${T7_DISK}-part1"
SANDISK_PART='/dev/disk/by-id/usb-SanDisk_Extreme_55AE_323135303458343031333231-0:0-part1'
LABEL='pve-backup'
VMID=100

need() {
  command -v "$1" >/dev/null || {
    echo "ERROR: missing tool '$1' (PATH=$PATH)" >&2
    exit 1
  }
}
need qm
need wipefs
need sgdisk
need mkfs.ext4
need blkid
need findmnt
need lsblk

echo '=== current block devices ==='
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,TRAN

if [[ ! -b "$T7_DISK" ]]; then
  echo "ERROR: T7 not found at $T7_DISK" >&2
  exit 1
fi

# Config delete does not always hot-unplug; require VM stopped before wipe.
if qm status "$VMID" 2>/dev/null | grep -q running; then
  echo "ERROR: VM $VMID is still running." >&2
  echo "  virtiofsd holds /mnt/backup busy; QEMU may still hold the T7 open." >&2
  echo "  Run:  qm shutdown $VMID   # wait until stopped, or: qm stop $VMID" >&2
  echo "  Then re-run this script." >&2
  exit 1
fi

if pgrep -af 'virtiofsd.*shared-dir=/mnt/backup' >/dev/null 2>&1; then
  echo "ERROR: virtiofsd still sharing /mnt/backup — stop VM $VMID first." >&2
  pgrep -af 'virtiofsd.*shared-dir=/mnt/backup' || true
  exit 1
fi

if findmnt -n -S "$T7_PART" &>/dev/null || findmnt -n -S "$T7_DISK" &>/dev/null; then
  echo "ERROR: T7 is still mounted somewhere — unmount first." >&2
  findmnt -S "$T7_PART" || true
  exit 1
fi

# Refuse wipe if any process still has the T7 block device open.
if command -v fuser >/dev/null && fuser "$T7_DISK" "$T7_PART" 2>/dev/null; then
  echo "ERROR: something still has the T7 open (see fuser above)." >&2
  exit 1
fi

# Confirm models so we never wipe the wrong disk.
t7_model=$(cat /sys/block/"$(basename "$(readlink -f "$T7_DISK")")"/device/model 2>/dev/null || true)
echo "T7 model string: [$t7_model]"
if [[ "$t7_model" != *T7* && "$t7_model" != *PSSD* ]]; then
  echo "ERROR: refusing to wipe — model does not look like T7 Shield." >&2
  exit 1
fi

echo
echo "This will:"
echo "  1) umount /mnt/backup (SanDisk)"
echo "  2) wipe + GPT + ext4 LABEL=$LABEL on T7 (via sgdisk, not parted)"
echo "  3) point fstab /mnt/backup at T7 UUID"
echo "  4) mount and mkdir /mnt/backup/dump"
echo "  5) leave SanDisk unmounted (unplug when ready)"
echo
read -r -p "Type YES to continue: " ans
[[ "$ans" == YES ]] || { echo aborted; exit 1; }

echo '=== umount SanDisk /mnt/backup ==='
# Prefer systemd so fstab-generated mnt-backup.mount does not fight a raw umount.
if systemctl is-active --quiet mnt-backup.mount 2>/dev/null; then
  systemctl stop mnt-backup.mount
fi
if findmnt /mnt/backup &>/dev/null; then
  # Ensure no shell is sitting on the tree; kill only if still busy.
  if ! umount /mnt/backup 2>/tmp/umount-backup.err; then
    echo "umount failed: $(cat /tmp/umount-backup.err)"
    echo "Holders:"
    fuser -vm /mnt/backup 2>&1 || true
    lsof +f -- /mnt/backup 2>&1 | head -30 || true
    echo "Trying lazy unmount (safe here: we are retiring SanDisk, not remounting it)..."
    umount -l /mnt/backup
  fi
fi
if findmnt /mnt/backup &>/dev/null; then
  echo "ERROR: /mnt/backup still mounted after stop/umount." >&2
  findmnt /mnt/backup
  exit 1
fi

echo '=== wipe + partition T7 (sgdisk) ==='
# Clear old signatures on whole disk and any existing partitions.
wipefs -a "$T7_DISK" || true
# If an old partition node still exists, wipe it too before zap.
[[ -b "$T7_PART" ]] && wipefs -a "$T7_PART" || true
sgdisk --zap-all "$T7_DISK"
# New GPT, one Linux filesystem partition using the whole disk.
sgdisk -n 1:0:0 -t 1:8300 -c 1:"$LABEL" "$T7_DISK"
# Refresh partition nodes (partprobe not always installed).
command -v partprobe >/dev/null && partprobe "$T7_DISK" || true
command -v udevadm >/dev/null && udevadm settle || sleep 1
# Wait for udev
for _ in $(seq 1 40); do
  [[ -b "$T7_PART" ]] && break
  sleep 0.25
done
[[ -b "$T7_PART" ]] || { echo "ERROR: $T7_PART did not appear" >&2; ls -l /dev/disk/by-id/usb-Samsung* || true; exit 1; }

echo '=== mkfs.ext4 ==='
mkfs.ext4 -F -L "$LABEL" "$T7_PART"
UUID=$(blkid -s UUID -o value "$T7_PART")
echo "New UUID=$UUID"

echo '=== fstab ==='
cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
# Remove any existing /mnt/backup lines, then add T7.
grep -v '[[:space:]]/mnt/backup[[:space:]]' /etc/fstab > /etc/fstab.new
printf 'UUID=%s /mnt/backup ext4 defaults,noatime 0 2\n' "$UUID" >> /etc/fstab.new
mv /etc/fstab.new /etc/fstab
echo '--- /etc/fstab (backup lines) ---'
grep backup /etc/fstab || true

echo '=== mount ==='
mkdir -p /mnt/backup
# fstab UUID changed — regenerate mnt-backup.mount before start
systemctl daemon-reload
if ! systemctl start mnt-backup.mount; then
  echo "systemctl start failed; trying mount(8)..."
  mount /mnt/backup
fi
# Must be the T7, not an empty dir on rpool
if ! findmnt -n -S "UUID=$UUID" /mnt/backup &>/dev/null && ! findmnt -n -S "$T7_PART" /mnt/backup &>/dev/null; then
  echo "ERROR: /mnt/backup is not mounted on T7 (UUID=$UUID)." >&2
  findmnt /mnt/backup || true
  systemctl status mnt-backup.mount --no-pager || true
  exit 1
fi
mkdir -p /mnt/backup/dump
chmod 755 /mnt/backup /mnt/backup/dump

echo '=== verify ==='
findmnt /mnt/backup
df -h /mnt/backup
ls -la /mnt/backup
blkid "$(findmnt -n -o SOURCE /mnt/backup)"
echo
echo "SanDisk should be unmounted. Optional: unplug Extreme 55AE when convenient."
if [[ -b "$SANDISK_PART" ]]; then
  echo "SanDisk still present: $SANDISK_PART"
fi
echo
echo "Done. Guest virtiofs tag pve-backup still points at host /mnt/backup."
echo "On guest: mount | grep pve-backup; ls /mnt/pve-backup/dump"
echo "Then: fresh vzdump (or wait for schedule) + vzdump-b2 sync."
