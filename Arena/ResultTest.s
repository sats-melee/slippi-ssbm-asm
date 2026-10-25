# Executes the actual inline E8 result sender against synthetic MatchEnd data.
.include "Common/Common.s"
.set FN_EXITransferBuffer, MockEXI

.section .text
.global _start
_start:
load r13, 0x804e0000
load r8, 0x80479d30
load r9, 0x02000002 # Local Versus in-game
stw r9, 0(r8)
bl Init
load r20, ExpectedFFA2
bl SetExpected
li r3, 0x31
li r4, 0x41
li r7, 0x71
li r10, 77
mtctr r10
load r10, 0x20000000
mtxer r10
load r10, 0x12345678
mtcrf 0xff, r10
bl Hook
mfcr r8
load r9, 0x12345678
cmpw r8, r9
bne FailedCR
mfctr r8
cmpwi r8, 77
bne FailedCTR
mfxer r8
load r9, 0x20000000
cmpw r8, r9
bne FailedXER
cmpwi r3, 0x31
bne FailedRegisters
cmpwi r4, 0x41
bne FailedRegisters
cmpwi r7, 0x71
bne FailedRegisters

# Four-player FFA, CPU P4 wins normally.
load r30, 0x80479da4
li r0, 0
stb r0, 0x1A8(r30) # P3 human
li r0, 1
stb r0, 0x250(r30) # P4 CPU
stb r0, 0x5E(r30) # P1 loses
li r0, 2
stb r0, 0x106(r30) # P2 rank2
li r0, 3
stb r0, 0x1AE(r30) # P3 rank3
li r0, 0
stb r0, 0x256(r30) # P4 rank0
load r20, ExpectedFFA4CPU
bl SetExpected
bl Hook

# Red P1/P3 win; P3's individual rank is NOT zero (already eliminated).
li r0, 1
stb r0, 6(r30)
stb r0, 0x256(r30) # P4 loses individually
stb r0, 0x26(r30) # Red active
stb r0, 0x32(r30) # Blue active
stb r0, 0x31(r30) # Blue team rank1
stb r0, 0x107(r30) # P2 Blue
stb r0, 0x257(r30) # P4 Blue
li r0, 0
stb r0, 0x5E(r30) # P1 individual winner
stb r0, 0x25(r30) # Red team rank0
load r20, ExpectedRed
bl SetExpected
bl Hook

# Timeout: Blue team wins even though P1 remains individually rank zero.
li r0, 1
stb r0, 4(r30)
stb r0, 0x25(r30)
li r0, 0
stb r0, 0x31(r30)
load r20, ExpectedBlueTimeout
bl SetExpected
bl Hook

# Both team rankings tied at zero: never invent a winner.
stb r0, 0x25(r30)
load r20, ExpectedTeamTie
bl SetExpected
bl Hook

# No contest: preserve roster, report no winner regardless of stale ranks.
li r0, 7
stb r0, 4(r30)
load r20, ExpectedNoContest
bl SetExpected
bl Hook

# Missing team standings: do not authorize a team result.
li r0, 2
stb r0, 4(r30)
li r0, 1
stb r0, 0x31(r30)
li r0, 0
stb r0, 0x32(r30)
load r20, ExpectedInvalidStandings
bl SetExpected
bl Hook

# Out-of-range team IDs are transmitted for host rejection, with no winner.
li r0, 4
stb r0, 0x257(r30)
load r20, ExpectedInvalidTeam
bl SetExpected
bl Hook

# No result traffic in online or replay scenes.
load r8, Calls
lwz r21, 0(r8)
load r8, 0x80479d30
load r9, 0x08000002
stw r9, 0(r8)
bl Hook
load r8, Calls
lwz r9, 0(r8)
cmpw r9, r21
bne FailedOnline
load r8, 0x80479d30
load r9, 0x0e000002
stw r9, 0(r8)
bl Hook
load r8, Calls
lwz r9, 0(r8)
cmpw r9, r21
bne FailedOnline
cmpwi r9, 8
bne FailedCalls
li r3, 0
b Exit

Init:
load r30, 0x80479da4
li r0, 0
li r8, 0
Clear:
stwx r0, r30, r8
addi r8, r8, 4
cmpwi r8, 0x500
blt Clear
li r0, 2
stb r0, 4(r30)
li r0, 1
stb r0, 0x106(r30)
li r0, 3
stb r0, 0x1A8(r30)
stb r0, 0x250(r30)
stb r0, 0x2F8(r30)
stb r0, 0x3A0(r30)
blr

SetExpected:
load r8, Expected
stw r20, 0(r8)
blr

MockEXI:
cmpwi r4, 16
bne FailedPacket
cmpwi r5, CONST_ExiWrite
bne FailedPacket
load r8, Expected
lwz r8, 0(r8)
li r9, 0
CheckPacket:
lbzx r10, r3, r9
lbzx r11, r8, r9
cmpw r10, r11
bne FailedPacket
addi r9, r9, 1
cmpwi r9, 16
blt CheckPacket
load r8, Calls
lwz r9, 0(r8)
addi r9, r9, 1
stw r9, 0(r8)
li r3, -1
li r4, -1
li r7, -1
li r8, 0
mtxer r8
mtctr r8
cmpwi r8, 0
blr

FailedCR: li r3, 1
b Exit
FailedCTR: li r3, 2
b Exit
FailedXER: li r3, 3
b Exit
FailedRegisters: li r3, 4
b Exit
FailedPacket: li r3, 5
b Exit
FailedOnline: li r3, 6
b Exit
FailedCalls: li r3, 7
Exit:
li r0, 1
sc

Hook:
.include "Arena/SendResult.s"
blr

.section .data
ExpectedFFA2: .byte 0xE8,1,2,0,3,1,255,0,0,0,3,3,255,255,255,255
ExpectedFFA4CPU: .byte 0xE8,1,2,0,15,8,255,0,0,0,0,1,255,255,255,255
ExpectedRed: .byte 0xE8,1,2,1,15,5,0,0,0,0,0,1,0,1,0,1
ExpectedBlueTimeout: .byte 0xE8,1,1,1,15,10,1,0,0,0,0,1,0,1,0,1
ExpectedTeamTie: .byte 0xE8,1,1,1,15,0,255,0,0,0,0,1,0,1,0,1
ExpectedNoContest: .byte 0xE8,1,7,1,15,0,255,0,0,0,0,1,0,1,0,1
ExpectedInvalidStandings: .byte 0xE8,1,2,1,15,0,255,0,0,0,0,1,0,1,0,1
ExpectedInvalidTeam: .byte 0xE8,1,2,1,15,0,255,0,0,0,0,1,0,1,0,4
.align 2
Expected: .long 0
Calls: .long 0
.section .bss
.space 0x100000
