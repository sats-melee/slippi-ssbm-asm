#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build-tools/tests
powerpc-linux-gnu-as -mregnames --defsym STG_EXIIndex=1 --defsym SATS_ARENA=1 \
  -I . Arena/HookTest.s -o build-tools/tests/hook.o
powerpc-linux-gnu-ld -Ttext 0x10000 --section-start=.bss=0x80400000 \
  build-tools/tests/hook.o -o build-tools/tests/hook-test
qemu-ppc build-tools/tests/hook-test
echo "PASS: PPC hook capture, source guards, CR/argument preservation, float preservation, overflow bounds"
