# Omarchy on the MacBook Pro 14-inch M4 Pro (J614s)

Bringing [Omarchy](https://omarchy.org) (Arch Linux + Hyprland) to the **14-inch MacBook Pro with
M4 Pro**, board `J614s`, on top of the [Aurora Silicon](https://github.com/aurora-silicon) stack.

> **Status: early bring-up.** Nothing has booted on a J614s yet. The patches here compile but are
> unproven on hardware. Do not install anything from this repository on a Mac you depend on.

## Why this exists

As of late October 2026 no Linux distribution installs on an M4 Pro MacBook Pro:

- [Asahi Linux](https://asahilinux.org) has M4 at early bring-up (NVMe, PCIe, SMP), no GPU, not in
  the installer.
- Aurora Silicon's installer admits M1, M2 and M3 boards only.
- One developer ([jgoyvaerts/omarchy-m4](https://github.com/jgoyvaerts/omarchy-m4)) runs Omarchy
  with GPU acceleration on the **16-inch** M4 Pro (`J616s`), and Aurora's bootloader
  [aura](https://github.com/aurora-silicon/aura) and kernel now carry that board upstream.

The 14-inch uses the same T6040 die as the 16-inch. In the 48 GB configuration it is the same
14-core CPU / 20-core GPU bin. What differs is the board: panel, speakers, thermals, Wi-Fi antenna
profile, per-unit calibration. On the M1 Pro, Asahi's 14-inch and 16-inch trees differ in exactly
six properties. This repository does that work for the M4 Pro.

## Approach

Build on Aurora's stack, not on a one-off loader:

| Component | Upstream | What J614s needs |
|---|---|---|
| Bootloader | `aurora-silicon/aura` (m1n1 fork; tested on J616s) | admit `apple,j614s` in the T6041 display hand-off |
| Kernel | `aurora-silicon/linux`, branch `integration/aurora` | `t6040-j614s.dts`, macaudio and SEP profile entries |
| GPU userspace | `aurora-silicon/mesa` | nothing board-specific expected |
| Desktop | Omarchy aarch64 + `jgoyvaerts/omarchy-m4` userspace packages | board names in speaker/UCM configs |

Bring-up order, safest first:

1. Dump the Mac's device tree and firmware from macOS (read-only, `scripts/mac-dump.sh`).
2. Generate the J614s device tree from that dump.
3. RAM-boot Linux over USB-C from a Linux host with aura's proxy. Nothing touches the SSD.
4. Only once a desktop comes up: partition, install aura Stage 1 from Recovery, install Arch Linux
   ARM and Omarchy.

The full work-item list and the risk notes are in [PLAN.md](PLAN.md).

## Layout

```
PLAN.md                  the plan, work items, bring-up order, risks
patches/aurora-linux/    kernel patches against aurora-silicon/linux integration/aurora
patches/aura/            bootloader patches against aurora-silicon/aura main
scripts/mac-dump.sh      run on macOS: collects the ADT, model, firmware and disk info (read-only)
scripts/fetch-upstream.sh clones the upstream trees into upstream/ (ignored by git)
```

Not in this repository, by design: the Apple Device Tree dump, extracted Apple/Broadcom firmware
and per-unit calibration. They identify one machine and cannot be redistributed.

## Hardware

| | |
|---|---|
| Machine | MacBook Pro 14-inch, M4 Pro, 48 GB, 1 TB |
| Board | J614s (ADT `target-type`) |
| SoC | T6040 (`chip-id` 0x6040) |
| Reference board | J616s, MacBook Pro 16-inch M4 Pro |

## Build host

An x86_64 Arch Linux machine with Docker (aarch64 containers via `qemu-user-static` binfmt), the
`aarch64-linux-gnu` GCC cross toolchain, and Rust with the `aarch64-unknown-none-softfloat` target.
aura cross-builds with `make ARCH=aarch64-linux-gnu-`. Device trees build with
`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- dtbs`. The full kernel follows Aurora's
`alarm-aurora` recipe: Rust 1.99.0, LLVM, Aurora's patched bindgen.

## Credits

This builds directly on the work of the Asahi Linux project, Aurora Silicon, Jonathan Goyvaerts'
J616s port, and the Omarchy Mac team. Kernel and bootloader patches carry their upstream licences
(GPL-2.0 for the kernel, GPL-2.0-only / MIT for aura). The scripts and documents in this repository
are MIT licensed.
