#!/usr/bin/bash
## setup auto-unlock LUKS2 encrypted for a specified disk on Fedora/Silverblue/maybe others
##
## modified by ion-ize
## modified date: 05/15/2025
## modification reason: The previous script would only enable LUKS TPM unlock for the
## root disk, this will now allow any LUKS encrypted disk to be unlocked with the TPM.

set -eou pipefail

[ "$UID" -eq 0 ] || { echo "This script must be run as root."; exit 1;}

echo "WARNING: Do NOT use this if your CPU is vulnerable to faulTPM!"
echo "All AMD Zen2 and Zen3 Processors are known to be affected!"
echo "All AMD Zen1 processors are also likely affected, with Zen4 unknown!"
echo "If you have an AMD CPU, you likely shouldn't use this!"
echo "----------------------------------------------------------------------------"
echo "This script uses systemd-cryptenroll to enable TPM2 auto-unlock."
echo "You can review systemd-cryptenroll's manpage for more information."
echo "This script will modify your system."
echo "It will enable TPM2 auto-unlock of your LUKS partition for your root device!"
echo "It will bind to PCR 7 and 14 which is tied to your secureboot and moklist state."
read -p "Are you sure are good with this and want to enable TPM2 auto-unlock? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1 # handle exits from shell or function but don't exit interactive shell
fi

# Get list of all LUKS encrypted disks
echo "Scanning for LUKS encrypted disks..."
#echo "Debug: Running lsblk to list block devices..."
LUKS_DISKS=($(lsblk -o NAME,UUID,SIZE,FSTYPE,MOUNTPOINT -rn | awk '$4 == "crypto_LUKS" {print $1 "|" $2 "|" $3 "|" $4}'))
#echo "Debug: Found LUKS disks: ${LUKS_DISKS[@]}"

if [ ${#LUKS_DISKS[@]} -eq 0 ]; then
  echo "No LUKS encrypted disks found."
  exit 1
fi

echo "Available LUKS encrypted disks:"
for i in "${!LUKS_DISKS[@]}"; do
  IFS='|' read -r DEVICE UUID SIZE FSTYPE <<< "${LUKS_DISKS[$i]}"
  echo "$i) Device: /dev/${DEVICE}, UUID: ${UUID}, Size: ${SIZE}, FS Type: ${FSTYPE}"
done

read -p "Please select the target disk (0-$((${#LUKS_DISKS[@]} - 1))): " -r
echo
if [[ ! $REPLY =~ ^[0-9]+$ ]] || (( REPLY < 0 || REPLY >= ${#LUKS_DISKS[@]} )); then
  echo "Invalid selection."
  exit 1
fi

IFS='|' read -r DEVICE UUID SIZE FSTYPE <<< "${LUKS_DISKS[$REPLY]}"
DISK_UUID="${UUID}"
CRYPT_DISK="/dev/disk/by-uuid/$DISK_UUID"

# Check to make sure crypt disk exists
if [[ ! -L "$CRYPT_DISK" ]]; then
  echo "LUKS device not listed in block devices."
  echo "Exiting..."
  exit 1
fi


# Ask to add a LUKS unlock PIN in addition to the TPM2 key.
SET_PIN_ARG=""
read -p "Would you like to set a PIN? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  SET_PIN_ARG=" --tpm2-with-pin=yes "
fi

if cryptsetup luksDump "$CRYPT_DISK" | grep systemd-tpm2 > /dev/null; then
  KEYSLOT=$(cryptsetup luksDump "$CRYPT_DISK" | sed -n '/systemd-tpm2$/,/Keyslot:/p' | grep Keyslot|awk '{print $2}')
  echo "TPM2 already present in LUKS keyslot $KEYSLOT of $CRYPT_DISK."
  read -p "Wipe it and re-enroll? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemd-cryptenroll --wipe-slot=tpm2 "$CRYPT_DISK"
  else
    echo
    echo "Either clear the existing TPM2 keyslot before retrying, else choose 'y' next time."
    echo "Exiting..."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
  fi
fi

## Run crypt enroll
echo "Enrolling TPM2 unlock requires your existing LUKS2 unlock password"
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7+14 $SET_PIN_ARG "$CRYPT_DISK"


if lsinitrd 2>&1 | grep -q tpm2-tss > /dev/null; then
  ## add tpm2-tss to initramfs
  if rpm-ostree initramfs | grep tpm2 > /dev/null; then
    echo "TPM2 already present in rpm-ostree initramfs config."
    rpm-ostree initramfs
    echo "Re-running initramfs to pickup changes above."
  fi
  rpm-ostree initramfs --enable --arg=--force-add --arg=tpm2-tss
else
  ## initramfs already containts tpm2-tss
  echo "TPM2 already present in initramfs."
fi

## Now reboot
echo
echo "TPM2 LUKS auto-unlock configured for disk /dev/${DEVICE}. Reboot now."


# References:
#  https://www.reddit.com/r/Fedora/comments/uo4ufq/any_way_to_get_systemdcryptenroll_working_on/
#  https://0pointer.net/blog/unlocking-luks2-volumes-with-tpm2-fido2-pkcs11-security-hardware-on-systemd-248.html
