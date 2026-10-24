# Linux/PPC diagnostic harness. Executes the actual hook in qemu-ppc; no game/ROM.
.include "Common/Common.s"
.include "Recording/Recording.s"
.include "Online/Online.s"

.section .text
.global _start
_start:
  # Synthetic game address space, backed by the fixed BSS mapping below.
  load r13, 0x804e0000
  load r8, 0x80410000
  stw r8, primaryDataBuffer(r13)
  li r9, 123
  stw r9, frameIndex(r13)
  stw r9, RDB_ARENA_FRAME(r8)
  li r9, CMD_ARENA_CREDIT_BATCH
  stb r9, RDB_ARENA_TX(r8)
  load r9, 0x80479d30
  load r10, 0x02000002
  stw r10, 0(r9)

  li r3, 0
  li r4, 0
  li r5, 1
  li r6, 0
  li r7, 9
  load r9, damage
  lfs f1, 0(r9)
  load r9, 0x12345678
  mtcrf 0xff, r9
  bl ArenaHook
  mfcr r8
  load r9, 0x12345678
  cmpw r8, r9
  bne FailedCR
  cmpwi r3, 0
  bne FailedRegisters
  cmpwi r5, 1
  bne FailedRegisters
  cmpwi r7, 9
  bne FailedRegisters
  load r8, 0x80410000
  lbz r9, RDB_ARENA_COUNT(r8)
  cmpwi r9, 1
  bne FailedCount
  lbz r9, RDB_ARENA_RECORDS(r8)
  cmpwi r9, 0
  bne FailedRecord
  lbz r9, RDB_ARENA_RECORDS+2(r8)
  cmpwi r9, 1
  bne FailedRecord
  lwz r9, RDB_ARENA_RECORDS+4(r8)
  cmpwi r9, 9
  bne FailedRecord
  lwz r9, RDB_ARENA_RECORDS+8(r8)
  load r10, 0x41200000
  cmpw r9, r10
  bne FailedFloat
  stfs f1, RDB_ARENA_RECORDS+20(r8)
  lwz r9, RDB_ARENA_RECORDS+20(r8)
  cmpw r9, r10
  bne FailedFloat

  # Self credit and out-of-range attacker are not captured.
  li r3, 1
  bl ArenaHook
  li r3, 6
  bl ArenaHook
  lbz r9, RDB_ARENA_COUNT(r8)
  cmpwi r9, 1
  bne FailedGuards
  # Online mode is inert.
  load r9, 0x80479d30
  load r10, 0x08000002
  stw r10, 0(r9)
  li r3, 0
  bl ArenaHook
  lbz r9, RDB_ARENA_COUNT(r8)
  cmpwi r9, 1
  bne FailedGuards
  # Stale frame buffers are inert.
  load r9, 0x80479d30
  load r10, 0x02000002
  stw r10, 0(r9)
  li r9, 122
  stw r9, RDB_ARENA_FRAME(r8)
  bl ArenaHook
  lbz r9, RDB_ARENA_COUNT(r8)
  cmpwi r9, 1
  bne FailedGuards
  # Overflow never writes record 33 or increments beyond capacity.
  li r9, 123
  stw r9, RDB_ARENA_FRAME(r8)
  li r9, 32
  stb r9, RDB_ARENA_COUNT(r8)
  load r9, 0x55aa55aa
  stw r9, RDB_LEN(r8)
  bl ArenaHook
  lbz r9, RDB_ARENA_COUNT(r8)
  cmpwi r9, 32
  bne FailedBounds
  lbz r9, RDB_ARENA_OVERFLOW(r8)
  cmpwi r9, 1
  bne FailedBounds
  lwz r9, RDB_LEN(r8)
  load r10, 0x55aa55aa
  cmpw r9, r10
  bne FailedBounds
  li r3, 0
  b Exit
FailedCR: li r3, 1
  b Exit
FailedRegisters: li r3, 2
  b Exit
FailedCount: li r3, 3
  b Exit
FailedRecord: li r3, 4
  b Exit
FailedFloat: li r3, 5
  b Exit
FailedGuards: li r3, 6
  b Exit
FailedBounds: li r3, 7
Exit:
  li r0, 1
  sc

ArenaHook:
.include "Arena/CaptureCredit.asm"
blr

.section .data
damage: .long 0x41200000
.section .bss
.space 0x100000
