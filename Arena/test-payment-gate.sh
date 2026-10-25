#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build-tools/tests
powerpc-linux-gnu-as -mregnames --defsym STG_EXIIndex=1 --defsym SATS_ARENA=1 \
  -I . Arena/PaymentGateTest.s -o build-tools/tests/payment-gate.o
powerpc-linux-gnu-ld -Ttext 0x10000 --section-start=.bss=0x803f0000 \
  build-tools/tests/payment-gate.o -o build-tools/tests/payment-gate-test
qemu-ppc build-tools/tests/payment-gate-test
echo "PASS: actual PPC payment hook, packet, denied/granted Start, register/CR/CTR/XER preservation, online exclusion"
