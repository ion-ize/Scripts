#!/bin/bash
set -x
sudo insmod /home/conor/git/hid-tmff2/hid-tmff-new.ko
sudo cp /home/conor/git/hid-tmff2/udev/99-thrustmaster.rules /etc/udev/rules.d/99-thrustmaster.rules
sudo cp /home/conor/git/hid-tmff2/udev/71-thrustmaster-steamdeck.rules /etc/udev/rules.d/71-thrustmaster-steamdeck.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
if mokutil --sb-state | grep "SecureBoot enabled" > /dev/null; then
  # Only prompt the user if we are in an interactive terminal
  if [ -t 0 ]; then
    echo "Secure Boot is enabled. You may need to import the signing key."
    read -p "Do you want to import the signing key now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      sudo mokutil --import ~/git/hid-tmff2/signing_key.x509
      echo "The signing key has been imported. You will need to enroll it on the next reboot."
    else
      echo "Skipping key import. If the driver fails to load, you may need to import the key manually."
    fi
  else
    echo "Secure Boot is enabled, but running in non-interactive mode."
    echo "Cannot prompt to import MOK key. Please run this script manually from a terminal to import the key if needed."
  fi
fi
