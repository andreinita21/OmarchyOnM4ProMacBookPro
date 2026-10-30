#!/bin/bash
# Clone the upstream trees this port builds on, into upstream/ (ignored by git).
# GitHub rate-limits bulk clones from one IP; the loop retries with backoff.
set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p upstream && cd upstream

declare -A want=(
  [aura]="https://github.com/aurora-silicon/aura main"
  [aurora-linux]="https://github.com/aurora-silicon/linux integration/aurora"
  [mesa]="https://github.com/aurora-silicon/mesa main"
  [omarchy-m4]="https://github.com/jgoyvaerts/omarchy-m4 main"
  [m4-loader]="https://github.com/jgoyvaerts/m4-loader main"
  [jg-linux]="https://github.com/jgoyvaerts/linux m4/aurora-7.3"
)

for attempt in 1 2 3 4 5 6; do
  left=0
  for name in "${!want[@]}"; do
    [ -e "$name/.git" ] && continue
    set -- ${want[$name]}
    echo "$(date +%T) attempt $attempt: $name ($2)"
    if timeout 1500 git clone -q --depth 1 -b "$2" "$1" "$name"; then
      echo "$(date +%T) OK $name"
    else
      rm -rf "$name"; left=1
    fi
  done
  [ $left = 0 ] && { echo "all upstream trees present"; exit 0; }
  sleep $((attempt * 600))
done
echo "gave up; rerun later" >&2
exit 1
