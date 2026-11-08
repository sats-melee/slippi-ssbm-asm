#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build-tools/tests
powerpc-linux-gnu-as -mregnames --defsym STG_EXIIndex=1 --defsym SATS_ARENA=1 \
  -I . Arena/RoomCSSTest.s -o build-tools/tests/room-css.o
powerpc-linux-gnu-ld -Ttext 0x10000 --section-start=.bss=0x80000000 \
  build-tools/tests/room-css.o -o build-tools/tests/room-css-test
qemu-ppc build-tools/tests/room-css-test
echo "PASS: actual PPC room CSS mode, all four canonical team colors, FFA reset, local CSS unchanged"
