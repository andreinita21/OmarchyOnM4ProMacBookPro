# Patches

Apply with `git am` on the upstream commit each series is based on.

| Series | Upstream | Base commit (2026-10-30) |
|---|---|---|
| `aurora-linux/` | aurora-silicon/linux, branch `integration/aurora` | `202e4d0a8` |
| `aura/` | aurora-silicon/aura, branch `main` | `0ca7bf8` |

Status: drafts. They compile (`dtbs`, aura cross-build) and have not booted on a J614s.
Lines marked `TODO(J614s ADT)` hold J616s values until a J614s device tree dump replaces them.
