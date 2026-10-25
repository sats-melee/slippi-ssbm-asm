#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build-tools/tests
powerpc-linux-gnu-as -mregnames --defsym STG_EXIIndex=1 --defsym SATS_ARENA=1 \
  -I . Arena/ResultTest.s -o build-tools/tests/result.o
powerpc-linux-gnu-ld -Ttext 0x10000 --section-start=.bss=0x803f0000 \
  build-tools/tests/result.o -o build-tools/tests/result-test
qemu-ppc build-tools/tests/result-test
echo "PASS: actual PPC result sender, FFA/CPU, team stocks/timeout, eliminated teammates, ties/no contest/invalid data, register/CR/CTR/XER preservation, online/replay exclusion"
