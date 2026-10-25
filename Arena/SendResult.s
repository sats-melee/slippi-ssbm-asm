# Inline extension of Recording/SendGameEnd.asm, after CreateMatchEndData.
# Not a standalone injection. Only local Versus writes the private E8 message.
# Actual NTSC-U 1.02 result offsets verified against gm_801654A0:
# team rank +0x25, active +0x26, stride 0x0C (table base +0x1C).
backupall
mfcr r0
stw r0, 0x80(r1)
mfctr r0
stw r0, 0x84(r1)
mfxer r0
stw r0, 0x88(r1)

getMinorMajor r3
cmpwi r3, SCENE_VERSUS_IN_GAME
bne ArenaResultExit
addi r31, r1, 0xA0
byteAlign32 r31
li r0, 0
stw r0, 0(r31)
stw r0, 4(r31)
stw r0, 8(r31)
stw r0, 12(r31)
li r0, 0xE8
stb r0, 0(r31)
li r0, 1
stb r0, 1(r31)
li r0, 255
stb r0, 6(r31)
load r30, 0x80479da4
lbz r0, 4(r30) # MatchEnd.outcome
stb r0, 2(r31)
lbz r28, 6(r30) # MatchEnd.is_teams
stb r28, 3(r31)
li r27, 0 # Active player mask
li r23, 0 # Active team mask
li r22, 1 # Valid roster flag
li r21, 0 # Participant count
li r29, 0
ArenaResultRoster:
mulli r4, r29, 0xA8
add r4, r30, r4
lbz r0, 0x58(r4) # MatchPlayerData.pkind
addi r5, r29, 8
stbx r0, r31, r5
li r3, 255
cmplwi r0, 1
ble ArenaResultActive
cmpwi r0, 3
beq ArenaResultStoreTeam
li r22, 0
b ArenaResultStoreTeam
ArenaResultActive:
addi r21, r21, 1
li r5, 1
slw r5, r5, r29
or r27, r27, r5
cmpwi r28, 0
beq ArenaResultStoreTeam
cmpwi r28, 1
bne ArenaResultInvalidTeam
lbz r3, 0x5F(r4) # MatchPlayerData.team
cmplwi r3, 2
bgt ArenaResultInvalidTeam
li r5, 1
slw r5, r5, r3
or r23, r23, r5
b ArenaResultStoreTeam
ArenaResultInvalidTeam:
li r22, 0
ArenaResultStoreTeam:
addi r5, r29, 12
stbx r3, r31, r5
addi r29, r29, 1
cmpwi r29, 4
blt ArenaResultRoster
stb r27, 4(r31)

# Only complete normal outcomes (timeout, stocks, stamina) can name a winner.
cmpwi r22, 1
bne ArenaResultSend
cmpwi r21, 2
blt ArenaResultSend
lbz r0, 2(r31)
cmplwi r0, 1
blt ArenaResultSend
cmplwi r0, 3
bgt ArenaResultSend
cmpwi r28, 0
beq ArenaResultFFA
cmpwi r28, 1
bne ArenaResultSend

# Find exactly one rank-zero active TEAM, independently of individual ranks.
li r24, 255 # Winner team
li r25, 0 # Number of tied rank-zero teams
li r29, 0
ArenaResultTeamRanks:
mulli r4, r29, 0x0C
add r4, r30, r4
li r5, 1
slw r5, r5, r29
and. r5, r5, r23
beq ArenaResultInactiveTeam
lbz r0, 0x26(r4)
cmpwi r0, 1
bne ArenaResultSend
lbz r0, 0x25(r4)
cmplwi r0, 2
bgt ArenaResultSend
cmpwi r0, 0
bne ArenaResultNextTeam
addi r25, r25, 1
mr r24, r29
b ArenaResultNextTeam
ArenaResultInactiveTeam:
lbz r0, 0x26(r4)
cmpwi r0, 0
bne ArenaResultSend
ArenaResultNextTeam:
addi r29, r29, 1
cmpwi r29, 3
blt ArenaResultTeamRanks
cmpwi r25, 1
bne ArenaResultSend
# A local four-slot game must not have active extra teams in standings.
lbz r0, 0x4A(r30)
cmpwi r0, 0
bne ArenaResultSend
lbz r0, 0x56(r30)
cmpwi r0, 0
bne ArenaResultSend
# At least two opposing sides must have participated.
addi r0, r23, -1
and. r0, r0, r23
beq ArenaResultSend
li r25, 0 # Winning player mask
li r29, 0
ArenaResultTeamMembers:
li r5, 1
slw r5, r5, r29
and. r0, r5, r27
beq ArenaResultNextMember
addi r4, r29, 12
lbzx r0, r31, r4
cmpw r0, r24
bne ArenaResultNextMember
or r25, r25, r5
ArenaResultNextMember:
addi r29, r29, 1
cmpwi r29, 4
blt ArenaResultTeamMembers
cmpwi r25, 0
beq ArenaResultSend
stb r24, 6(r31)
stb r25, 5(r31)
b ArenaResultSend

ArenaResultFFA:
li r25, 0 # Winning player mask
li r24, 0 # Number of tied rank-zero players
li r29, 0
ArenaResultIndividualRanks:
li r5, 1
slw r5, r5, r29
and. r0, r5, r27
beq ArenaResultNextIndividual
mulli r4, r29, 0xA8
add r4, r30, r4
lbz r0, 0x5E(r4)
cmplwi r0, 3
bgt ArenaResultSend
cmpwi r0, 0
bne ArenaResultNextIndividual
addi r24, r24, 1
or r25, r25, r5
ArenaResultNextIndividual:
addi r29, r29, 1
cmpwi r29, 4
blt ArenaResultIndividualRanks
cmpwi r24, 1
bne ArenaResultSend
stb r25, 5(r31)

ArenaResultSend:
mr r3, r31
li r4, 16
li r5, CONST_ExiWrite
branchl r12, FN_EXITransferBuffer
ArenaResultExit:
lwz r0, 0x88(r1)
mtxer r0
lwz r0, 0x84(r1)
mtctr r0
lwz r0, 0x80(r1)
mtcrf 0xff, r0
restoreall
