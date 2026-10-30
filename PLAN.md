# Omarchy on the 14-inch MacBook Pro M4 Pro (J614s): porting plan

Written 2026-10-30 from the state of the aurora-silicon and jgoyvaerts repositories on that day.

## 0. The machine

| | 16-inch M4 Pro (reference, works today) | 14-inch M4 Pro (this port) |
|---|---|---|
| Board (ADT `target-type`) | J616s | J614s |
| Model identifier | Mac16,7 | Mac16,8 (verify with `sysctl hw.model`) |
| SoC (`chip-id`) | 0x6040 (T6040, `arm-io,t6041`) | 0x6040, identical die |
| macOS on the main volume | 26.6.2 stub for Linux; system firmware mBoot-20457.1.29 | **27.0.1 (26A434)**, system firmware mBoot-20457.1.29 (read 2026-10-30) |
| Wi-Fi island (`module-instance`) | hostomel | **mriya** |
| Disk | | 1 TB; 314 GB free in the APFS container; Time Machine volume on an external 1 TB drive |
| CPU / GPU | 14 CPU (10P+4E) / 20 GPU cores | **12 CPU (8P+4E) / 16 GPU cores** (Andrei's unit; a lower bin of the same die) |

Same silicon, different bin. Two P cores and four GPU cores are fused off. aura prunes CPU nodes by MPIDR
at boot and derives the active GPU core count from the fused mask, so the loader copes. The kernel GPU
driver does not yet: `drivers/gpu/drm/asahi/hw/t6040.rs` admits exactly `(2 clusters, 20 cores)` and the
compute operand-state buffer sizes were measured on the 20-core part. Admitting the 16-core layout is a
work item of its own (section 2). Everything else SoC-level (NVMe, PCIe, USB, DARTs, AOP, GPU driver, cpufreq, PMP) carries over.
What differs is the board: panel, speaker tuning, thermals/fans, Wi-Fi antenna profile, trackpad firmware,
per-unit calibration. On the M1 Pro, Asahi's 14-inch and 16-inch trees differ in exactly:
`compatible`/`model`, `panel` (compatible + width/height mm), `brcm,board-type` (Wi-Fi and BT),
`aop_audio` chassis name, `sound` compatible + model, and the Touch ID calibration file name.
Expect the same list here, plus fan curves.

## 0b. The firmware version pin (read from the Mac on 2026-10-30)

Everything Aurora has for T6040 is pinned to the **macOS 26.6.2 (25G83)** coprocessor firmware: aura's
display hand-off bails unless the OS firmware is 26.6.2 (`dcp_soc_t6041.os_fw = V26_6_2`), the GPU
driver admits only the 25G83 GPU firmware images (`hw/t6040.rs`), the ISP and AOP paths assume the same
build. Andrei's Mac runs 27.0.1 (26A434). This is not a blocker: on Apple Silicon the coprocessor
firmware comes from the macOS install that owns the boot policy, so the small stub macOS that Linux
boots through must be **26.6.2**, while the main macOS stays at 27.0.1. The 16-inch reference does
exactly this (its loader checks system firmware mBoot-20457.1.29 with OS firmware mBoot-18000.161.10).
Consequences:
- The device-tree values that follow the firmware build (ISP and GPU firmware regions, DAPF entries)
  must come from the ADT as seen when booting through the 26.6.2 stub, not from today's dump.
- Firmware for Linux (Wi-Fi, Bluetooth, camera setfile) is extracted from the 26.6.2 IPSW, as the
  Asahi installer does, not from the running 27.0.1.
- The stub's restore image is the one the Omarchy Mac installer engine (`.31`) and Aurora use for
  25G83: `UniversalMac_26.6.2_25G83_Restore.ipsw` at
  `https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75212/A2A24B94-1FC1-45A3-93F7-C51B02AF1F4D/UniversalMac_26.6.2_25G83_Restore.ipsw`
  (minimum iBoot `mBoot-18000.161.10`, minimum SFR `25.7.83.0.0,0`; this Mac's system firmware
  `mBoot-20457.1.29` is newer, which is the supported direction). The installer's admission tables
  (`CHIP_MIN_VER`, `DEVICES`, the IPSW `devices` list) do not include 0x6040 or `j614sap`; a developer
  run needs those entries added, as the engine did for `j700ap`. The engine notes that on 26.6.2 Asahi's
  Stage 1 made iBoot panic on an M3 Air and only Aurora's Stage 1 booted, so the stub's boot object
  must be aura from the start.
- There is no disk-free bring-up: aura must be installed as the stub's boot object (`kmutil` from
  recoveryOS) before the first proxy session. The stub plus ESP cost about 3 GB; the Linux root comes
  later. The RAM boot of Linux over USB-C still writes nothing to the root partition.

## 1. Which stack to build on

Two stacks boot Linux on the J616s today.

**A. jgoyvaerts' lab stack** (`jgoyvaerts/m4-loader`, `jgoyvaerts/linux` branch `m4/aurora-7.3`, `jgoyvaerts/omarchy-m4`).
Works daily with GPU, but the loader is bound to one machine: it compares 420 Apple Device Tree records
byte for byte (`src/standalone/gates.h`), hard-codes `J616s`/`Mac16,7`/firmware strings in
`dart-capture.c`, `bt-boot-current-adt.c`, `fixups.c`, `direct-peripheral-fdt.h`, `media-probe.c`, and
needs an opaque, unpublished `pcie.bin` blob to build. Its own author now feeds everything upstream.

**B. Aurora's stack** (`aurora-silicon/aura` bootloader, `aurora-silicon/linux` branch `integration/aurora`,
`aurora-silicon/mesa`). The aura PR that merged on 2026-10-29 was hardware-tested on a J616s (Stage 1 and
Stage 2 boot, 14 CPUs, three displays, Touch ID verify). The kernel carries an upstream-style
`t6040-j616s.dts` where the loader fills GPU operating points, calibration and firmware regions from the ADT
at boot. aura picks the device tree from the ADT `target-type`, so no gate table and no per-machine build.

**Decision: build on B.** Use A only as the reference for what J616s needed (its STATUS.md, its userspace
packages for Omarchy integration, speaker and jack configs).

J616s-specific spots found in aura so far:
- `src/kboot_display_handoff.c:394` `dcp_boards_t6041 = {"apple,j616s", NULL}`: the internal display
  hand-off is admitted per board. J614s must be added here (same T6041 display block, different panel).
- `src/kboot_gpu.c` `dt_set_gpu_t6040`: keyed on chip, reads efuse leakage; assumes 2 clusters x 10 cores.
  The kernel GPU driver refuses other fused core counts (GAPS.md). The 20-core part is fine; a 16-core
  M4 Pro would not be.

## 2. Work items

### Kernel (`aurora-silicon/linux`, branch `integration/aurora`)
1. `arch/arm64/boot/dts/apple/t6040-j614s.dts`: copy of `t6040-j616s.dts` with
   - `compatible = "apple,j614s", ...`, `model = "Apple MacBook Pro (14-inch, M4 Pro, Nov 2024)"`;
   - panel: `apple,panel-j614`, `width-mm = <302>`, `height-mm = <196>`, `adj-height-mm` from the ADT;
   - `aop_audio` `apple,chassis-name = "J614"`, sound `apple,j614-macaudio` / `apple,j614-macaudio-jack`,
     model strings "MacBook Pro J614";
   - firmware names `tpmtfw-j614s.bin`, `mesacal-j614s.bin`, `msrk-j614s.bin`;
   - `brcm,board-type` for Wi-Fi/BT: the island name from the firmware file set of this Mac
     (the 16-inch is `apple,hostomel`);
   - speaker amps: verify `/arm-io/i2c1/audio-speaker@38` (and i2c3) addresses, `speaker-config` sense slots,
     SDZ pin 54, IRQ pin 55 against the J614s ADT;
   - fan trips: the 14-inch runs hotter; start from the J616s macros, retune later;
   - SMC hwmon keys: every key must exist in this machine's SMC table (check with the proxy or macOS);
   - USB3 tunables: `t6040-j616s-usb3.dtsi` is generated from the J616s ADT; regenerate for J614s;
   - ISP/GPU firmware addresses and DAPF entries: taken from the ADT of the installed macOS build; must be
     regenerated for the user's macOS version in any case;
   - external display includes (`t6040-j616s-extdisp*.dtsi`): keep, verify port mapping.
2. `arch/arm64/boot/dts/apple/Makefile`: add `t6040-j614s.dtb` (and a `-tether` variant for RAM boots).
3. `sound/soc/apple/macaudio.c`: add `apple,j614-macaudio` and `apple,j614-macaudio-jack` entries reusing
   `macaudio_j616_cfg` / `macaudio_j616_jack_cfg`. Speaker safety (speakersafetyd `j614.conf`) and ALSA UCM
   `MacBook Pro J614.conf` in userspace.
4. Panel driver (`drivers/gpu/drm/apple/...`): find the `apple,panel-j616` match and add `apple,panel-j614`.
5. Anything else that greps for `j616` in drivers once the clone is in.

### GPU on the 16-core bin (kernel, `drivers/gpu/drm/asahi/`)
5b. `hw/t6040.rs`: `core_layout.cores` is `Some((2, 20))`; the probe refuses anything else
    (`g17/mod.rs`, "Unsupported GPU core layout"). Add a 16-core admission: `(2, 16)` with a
    `TWO_BY_EIGHT` operand state in `g17/fw/compute.rs`. That struct's own comment gives the layout
    rule (two preemption banks of three 0x800-byte records per core, then the bank end, then
    per-cluster tails), and the two measured constants `ONE_BY_SIX` and `TWO_BY_TEN` both satisfy:
    bank = cores*0x1800; r0a5c9 = bank; r10099 = bank + 0x405; r10091 = 2*bank + 0x400;
    r10229 = 2*bank + 0x800; r140a8 = r10229 + clusters*0x800; r0a5c1 = 5.
    For 2x8 that predicts r0a5c9 0x18000, r10099 0x18405, r10091 0x30400, r10229 0x30800,
    r140a8 0x31800. The buffer `size` does not follow an obvious rule (0x14000 and 0x44000 measured),
    so it must be measured: read what macOS programs on this unit through an aura proxy session before
    trusting any of these numbers. `Deflake::TWO_CLUSTERS` depends on cluster count only and should hold.
    aura's power model scales by `active_cores / 10` per cluster and reads the efuse leakage itself, so
    the loader side needs no change for the bin.

### Bootloader (`aurora-silicon/aura`)
6. Add `"apple,j614s"` to `dcp_boards_t6041` in `src/kboot_display_handoff.c`.
7. Build Stage 1 (`RELEASE=1 CHAINLOADING=1 BUILTIN_LOGO=aurora`) and Stage 2 (`+ ESP_STAGE2=1`).
8. Grep for any other `j616s`-only admission.

### Firmware and calibration (from the user's own macOS, never redistributed)
9. `asahi-fwextract` on the Asahi installer's `all_firmware.tar.gz` + kernelcache, plus
   `/usr/sbin/appleh16camerad` for the camera setfile (see `omarchy-m4/tools/firmware-from-macos.sh`).
10. Touch ID / trackpad per-unit files named `*-j614s.bin`.

### Omarchy userspace
11. Reuse `jgoyvaerts/omarchy-m4` packages (`m4-support`, `m4-tools`, Mesa) adapted to aura boot entries, or
    the `linux-aurora` package on Omarchy's edge channel once it carries `t6040-j614s.dtb`.

## 3. Bring-up order (safe to dangerous)

1. **Dump the ADT and firmware on macOS** (section 4). No change to the Mac.
2. **Generate the J614s device tree and loader patch** on the Arch build host from the dump.
3. **Stub + Stage 1**: create the 26.6.2 stub macOS and install aura Stage 1 as its boot object
   (Asahi-installer style, from 1TR). About 3 GB. Then **RAM boot over USB-C from the Arch laptop**
   using aura's proxy (`proxyclient`), with the `t6040-j614s-tether.dtb`. Nothing else is written. This is how the J616s was brought up
   (`aura/docs/j616s-bringup.md`). Iterate until the kernel reaches a shell, then display, then the rest.
4. **Partition**: shrink macOS, create a stub macOS (boot policy owner) and an ESP + Linux root, as the
   Asahi installer does. Needs ~110 GB free. Full backup first.
5. **Install aura Stage 1** on the stub's System volume from 1TR (`kmutil configure-boot ... --raw
   --entry-point 2048 --lowest-virtual-address 0`), Stage 2 + kernel + dtb + initramfs on the ESP
   (`aura/docs/j700-install.md`).
6. **Install Arch Linux ARM + Omarchy** on the root. Then packages, firmware, speakers, suspend.

## 4. What was collected from the Mac (done over SSH on 2026-10-30)

`scripts/mac-dump.sh` ran on the Mac; the result is in `mac-dump/` (ignored by git). Original
instructions, for another unit:

```sh
mkdir -p ~/j614s-dump && cd ~/j614s-dump
sw_vers > sw_vers.txt
sysctl hw.model hw.target hw.ncpu hw.memsize > sysctl.txt
system_profiler SPHardwareDataType SPDisplaysDataType SPAudioDataType > profiler.txt
ioreg -a -p IODeviceTree -l -w0 > adt.plist
ioreg -l -w0 -p IODeviceTree | grep -E '"(board-id|target-type|model|firmware-version|system-firmware-version|chip-id)"' > identity.txt
diskutil list > diskutil.txt
diskutil apfs list > apfs.txt
ls /usr/share/firmware/wifi/ > wifi-fw-dirs.txt
```

Open questions only this dump answers: exact board (`J614sAP`), macOS build (the device tree addresses and
the display/GPU firmware admission are per macOS build; the J616s work is on 26.6.2 / 25G83 with iBoot
mBoot-18000.161.10), GPU core count, Wi-Fi board island name, speaker amp addresses, SMC keys.

Also needed physically: a USB-C cable (data, not charge-only) between the Mac and the Arch laptop for the
aura proxy and RAM boots; a USB stick for 1TR; a full backup; ideally a second Mac for DFU restore.

## 5. Build host (this Arch laptop, x86_64)

- Docker daemon running; `qemu-user-static` binfmt for aarch64 containers present; the user is now in
  the `docker` group (re-login needed, `newgrp docker` meanwhile).
- `aarch64-linux-gnu-gcc` and binutils installed (aura builds with `make ARCH=aarch64-linux-gnu-`;
  needs `rustup target add aarch64-unknown-none-softfloat`).
- Kernel build: cross-compile with clang/rust (Asahi kernels need Rust) or inside an aarch64 container.
- Repos under `upstream/`: `m4-loader`, `omarchy-m4`, `mesa`, `aura`, `linux-m4` (jgoyvaerts 7.3 branch).

## 6. Risks

- No J614s has ever booted this stack, and no 16-core M4 Pro GPU has run the Aurora driver at all. Expect the display hand-off and GPU admission to need real work.
- A wrong Stage 1 leaves the stub macOS unbootable; the main macOS stays selectable at the startup picker.
  DFU restore via Apple Configurator from another Mac is the floor.
- macOS updates change the ADT and firmware addresses; the kernel tree and loader must follow.
- Never re-pair Bluetooth devices from Linux that macOS also uses.
