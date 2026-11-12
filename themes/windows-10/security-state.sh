#!/bin/bash
# One snapshot of Windows-Security-equivalent state for the Settings window.
set -euo pipefail

firewall="inactive"
if systemctl is-active --quiet ufw 2>/dev/null; then
  firewall="active"
elif systemctl is-active --quiet firewalld 2>/dev/null; then
  firewall="active"
fi

secure_boot="unknown"
efivar=$(find /sys/firmware/efi/efivars -maxdepth 1 -name 'SecureBoot-*' 2>/dev/null | head -n 1 || true)
if [[ -n $efivar && -r $efivar ]]; then
  value=$(od -An -t u1 "$efivar" 2>/dev/null | awk '{print $NF}')
  [[ $value == "1" ]] && secure_boot="on" || secure_boot="off"
fi

encrypted=false
if lsblk -o TYPE 2>/dev/null | grep -q '^crypt$'; then
  encrypted=true
fi

clamav="not-installed"
if systemctl list-unit-files clamav-daemon.service >/dev/null 2>&1; then
  clamav=$(systemctl is-active clamav-daemon 2>/dev/null || true)
  [[ -n $clamav ]] || clamav="inactive"
fi

tpm=false
[[ -e /sys/class/tpm/tpm0 ]] && tpm=true

snapshots=0
if command -v snapper >/dev/null 2>&1; then
  snapshots=$(snapper list-configs 2>/dev/null | tail -n +3 | grep -c '│' || true)
fi

jq -n \
  --arg firewall "$firewall" \
  --arg secureBoot "$secure_boot" \
  --argjson encrypted "$encrypted" \
  --arg clamav "$clamav" \
  --argjson tpm "$tpm" \
  --argjson snapshots "$snapshots" \
  '{
    firewall: $firewall,
    secureBoot: $secureBoot,
    encrypted: $encrypted,
    clamav: $clamav,
    tpm: $tpm,
    snapshots: $snapshots
  }'
