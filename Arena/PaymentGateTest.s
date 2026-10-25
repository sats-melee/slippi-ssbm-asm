# Execute the actual CSS injection against a synthetic EXI host under Linux/PPC.
.include "Common/Common.s"
.set FN_EXITransferBuffer, MockEXI

.section .text
.global _start
_start:
load r13, 0x804e0000
load r8, 0x80479d30
load r9, 0x02000000 # local CSS
stw r9, 0(r8)
load r8, 0x80410000
stw r8, -0x49f0(r13)
li r9, 1
stb r9, -0x49a9(r13) # PRESS START shown
load r8, 0x803f0dfc
li r9, 0
stb r9, 0x0b(r8)
stb r9, 0x2f(r8)
li r9, 3
stb r9, 0x53(r8)
stb r9, 0x77(r8)
li r9, 1
stb r9, 0x0e(r8)
li r9, 2
stb r9, 0x32(r8)

li r3, 0x31
li r4, 0x41
li r7, 0x1010 # START and Z
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
cmpwi r7, 0x10
bne FailedDeny

# Host grant replays the latched Start even when the original trigger is gone.
load r8, Response
li r9, 1
stb r9, 0(r8)
load r8, Expected
li r9, 0
stb r9, 3(r8)
li r7, 0x10
bl Hook
cmpwi r7, 0x1010
bne FailedGrant

# Four slots in teams: P1/P3 red, P2 blue, CPU P4 green.
load r8, 0x80410000
li r9, 1
stb r9, 0x18(r8)
load r8, 0x803f0dfc
li r9, 0
stb r9, 0x0a(r8)
stb r9, 0x52(r8)
stb r9, 0x53(r8)
li r9, 1
stb r9, 0x2e(r8)
stb r9, 0x77(r8)
li r9, 2
stb r9, 0x76(r8)
li r9, 3
stb r9, 0x56(r8)
li r9, 4
stb r9, 0x7a(r8)
load r8, Expected
li r9, 1
stb r9, 12(r8)
stb r9, 7(r8)
stb r9, 14(r8)
li r9, 0
stb r9, 6(r8)
stb r9, 13(r8)
stb r9, 15(r8)
li r9, 2
stb r9, 16(r8)
li r9, 3
stb r9, 10(r8)
li r9, 4
stb r9, 11(r8)
li r7, 0x10
bl Hook
cmpwi r7, 0x1010
bne FailedGrant

# A team color edit must appear in the next query.
load r8, 0x803f0dfc
li r9, 2
stb r9, 0x52(r8)
load r8, Expected
stb r9, 15(r8)
li r7, 0x10
bl Hook

# Closed slots and FFA never leak stale team colors.
load r8, 0x803f0dfc
li r9, 3
stb r9, 0x77(r8)
load r8, Expected
stb r9, 7(r8)
li r9, 255
stb r9, 16(r8)
li r7, 0x10
bl Hook
load r8, 0x80410000
li r9, 0
stb r9, 0x18(r8)
load r8, Expected
stb r9, 12(r8)
li r9, 255
stb r9, 13(r8)
stb r9, 14(r8)
stb r9, 15(r8)
li r7, 0x10
bl Hook

# Online CSS is untouched and must not query the host.
load r8, 0x80479d30
load r9, 0x08000000
stw r9, 0(r8)
li r7, 0x1010
load r8, Calls
lwz r20, 0(r8)
bl Hook
cmpwi r7, 0x1010
bne FailedOnline
load r8, Calls
lwz r9, 0(r8)
cmpw r9, r20
bne FailedOnline
li r3, 0
b Exit

MockEXI:
cmpwi r5, CONST_ExiRead
beq Read
cmpwi r4, 20
bne FailedPacket
load r8, Expected
li r9, 0
CheckPacket:
lbzx r10, r3, r9
lbzx r11, r8, r9
cmpw r10, r11
bne FailedPacket
addi r9, r9, 1
cmpwi r9, 20
blt CheckPacket
load r8, Calls
lwz r9, 0(r8)
addi r9, r9, 1
stw r9, 0(r8)
blr
Read:
load r8, Response
lbz r8, 0(r8)
stb r8, 0(r3)
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
FailedDeny: li r3, 5
b Exit
FailedGrant: li r3, 6
b Exit
FailedOnline: li r3, 7
b Exit
FailedPacket: li r3, 8
Exit:
li r0, 1
sc

Hook:
.include "Arena/PaymentGate.asm"
blr

.section .data
Expected: .byte 0xe7,2,1,1,0,0,3,3,1,2,0,0,0,255,255,255,255,0,0,0
.align 2
Response: .long 0
Calls: .long 0
.section .bss
.space 0x100000
