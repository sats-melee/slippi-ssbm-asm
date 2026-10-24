################################################################################
# Address: 8003eb30
# Annotation: Arena local game-credited damage (diagnostic, not applied percent)
################################################################################
.include "Common/Common.s"
.include "Recording/Recording.s"
.include "Online/Online.s"

# NTSC-U 1.02 pl_8003EB30 entry:
# f1 = nominal damage, r3 = attacker, r4 = attacker follower,
# r5 = victim, r6 = victim follower, r7 = attack ID.
# Verified displaced instruction: 7C0802A6 (mflr r0).
# No game function calls, allocation, or EXI inside this collision/credit hook.
backupall
mfcr r0
stw r0, 0x80(r1)

getMinorMajor r8
cmpwi r8, SCENE_VERSUS_IN_GAME
bne ArenaCreditExit
cmplwi r3, 3
bgt ArenaCreditExit
cmplwi r5, 3
bgt ArenaCreditExit
cmpw r3, r5
beq ArenaCreditExit

lwz r8, primaryDataBuffer(r13)
cmpwi r8, 0
beq ArenaCreditExit
# Only accept a packet initialized by this frame's frame-start procedure.
lbz r9, RDB_ARENA_TX(r8)
cmpwi r9, CMD_ARENA_CREDIT_BATCH
bne ArenaCreditExit
lwz r9, RDB_ARENA_FRAME(r8)
lwz r10, frameIndex(r13)
cmpw r9, r10
bne ArenaCreditExit

lbz r9, RDB_ARENA_COUNT(r8)
cmplwi r9, ARENA_MAX_CREDITS
bge ArenaCreditOverflow
mulli r10, r9, ARENA_RECORD_SIZE
addi r11, r8, RDB_ARENA_RECORDS
add r11, r11, r10
stb r3, 0(r11)
stb r4, 1(r11)
stb r5, 2(r11)
stb r6, 3(r11)
stw r7, 4(r11)
stfs f1, 8(r11)
addi r9, r9, 1
stb r9, RDB_ARENA_COUNT(r8)
b ArenaCreditExit

ArenaCreditOverflow:
li r9, 1
stb r9, RDB_ARENA_OVERFLOW(r8)

ArenaCreditExit:
lwz r0, 0x80(r1)
mtcrf 0xff, r0
restoreall
# Execute the original instruction, then the C2 trampoline resumes at 8003eb34.
mflr r0
