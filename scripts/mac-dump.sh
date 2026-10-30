#!/bin/sh
# Collect what the port needs from the MacBook itself. Run on macOS, in Terminal.
# Read-only: nothing here changes the disk, the boot policy or any setting.
#
#   sh mac-dump.sh            -> writes ~/j614s-dump/
#
# Copy the resulting folder to the Linux build host as mac-dump/ (it is in .gitignore:
# the ADT identifies your unit and must never be published).
set -eu
out="$HOME/j614s-dump"
mkdir -p "$out"
cd "$out"

sw_vers > sw_vers.txt
sysctl hw.model hw.target hw.ncpu hw.memsize hw.perflevel0.physicalcpu hw.perflevel1.physicalcpu > sysctl.txt
system_profiler SPHardwareDataType SPDisplaysDataType SPAudioDataType SPPowerDataType > profiler.txt

# The Apple Device Tree as macOS sees it (the loader reads the same tree from iBoot).
ioreg -a -p IODeviceTree -l -w0 > adt.plist
ioreg -l -w0 -p IODeviceTree | grep -E '"(board-id|target-type|model|firmware-version|system-firmware-version|chip-id|compatible)"' > identity.txt

# Disk layout, for the partitioning step much later.
diskutil list > diskutil.txt
diskutil apfs list > apfs.txt

# Which Wi-Fi/Bluetooth firmware islands this Mac ships (gives brcm,board-type).
ls /usr/share/firmware/wifi/ > wifi-fw-dirs.txt 2>/dev/null || true
ls /usr/share/firmware/bluetooth/ > bt-fw-dirs.txt 2>/dev/null || true

echo "written to $out:"
ls -la "$out"
