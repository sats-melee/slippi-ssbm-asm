################################################################################
# Address: 80263250
# Annotation: Arena funding gate when local CSS displays PRESS START
################################################################################
.include "Common/Common.s"

# fn_80262F44, NTSC-U 1.02: after the prompt's readiness calculation,
# before Start input is handled. Original instruction: lbz r0,-0x49ae(r13).
# r7 holds merged triggers. Existing online hook at 80263258 is untouched.
backupall
mfcr r0
stw r0, 0x80(r1)
mfctr r0
stw r0, 0x84(r1)
mfxer r0
stw r0, 0x88(r1)

getMinorMajor r3
cmpwi r3, SCENE_VERSUS_CSS
bne ArenaGateExit

# 32-byte aligned stack scratch, including space for EXI cache maintenance.
addi r31, r1, 0xA0
byteAlign32 r31
li r0, 0xE7
stb r0, 0(r31)
li r0, 2
stb r0, 1(r31)
lbz r3, -0x49a9(r13) # prompt animation/readiness counter
li r0, 0
cmpwi r3, 0
beq ArenaNotReady
li r0, 1
ArenaNotReady:
stb r0, 2(r31)
li r0, 0
andi. r3, r7, 0x1000
beq ArenaNoStart
lbz r3, -0x49ae(r13) # CSS input cooldown
cmpwi r3, 0
bne ArenaNoStart
li r0, 1
ArenaNoStart:
stb r0, 3(r31)

# v2: team mode, four CSSDoor.team bytes, and zeroed reserved bytes.
li r0, 0
stw r0, 16(r31)
lwz r3, -0x49f0(r13)
lbz r0, 0x18(r3) # CSSData.vs.start.rules.is_teams
stb r0, 12(r31)
load r30, 0x803F0DFC # CSS doors, stride 0x24
li r29, 0
ArenaRosterLoop:
mulli r4, r29, 0x24
add r4, r30, r4
lbz r0, 0x0b(r4) # human=0, CPU=1, closed=3
addi r5, r29, 4
stbx r0, r31, r5
lbz r0, 0x0e(r4) # selected character icon
addi r5, r29, 8
stbx r0, r31, r5
# Normalize inactive/FFA teams so irrelevant colors never change admission.
li r0, 255
lbz r5, 12(r31)
cmpwi r5, 1
bne ArenaStoreTeam
lbz r5, 0x0b(r4)
cmpwi r5, 1
bgt ArenaStoreTeam
lbz r0, 0x0a(r4) # CSSDoor.team: red=0, blue=1, green=2
ArenaStoreTeam:
addi r5, r29, 13
stbx r0, r31, r5
addi r29, r29, 1
cmpwi r29, 4
blt ArenaRosterLoop

mr r3, r31
li r4, 20
li r5, CONST_ExiWrite
branchl r12, FN_EXITransferBuffer
# Default denial before reading the response.
li r0, 0
stb r0, 0(r31)
mr r3, r31
li r4, 1
li r5, CONST_ExiRead
branchl r12, FN_EXITransferBuffer

# r7's saved slot: backupall stores r3 at 8, r7 at 24.
lwz r7, 0x18(r1)
load r0, 0xffffefff
and r7, r7, r0 # block Start while the host is waiting or unavailable
lbz r0, 0(r31)
cmpwi r0, 1
bne ArenaStoreInput
ori r7, r7, 0x1000 # replay the latched Start after confirmed funding
ArenaStoreInput:
stw r7, 0x18(r1)

ArenaGateExit:
lwz r0, 0x88(r1)
mtxer r0
lwz r0, 0x84(r1)
mtctr r0
lwz r0, 0x80(r1)
mtcrf 0xff, r0
restoreall
lbz r0, -0x49ae(r13)
