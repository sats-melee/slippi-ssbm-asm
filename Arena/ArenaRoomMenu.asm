################################################################################
# Address: 0x8022afec # Main-menu model update
################################################################################
.include "Common/Common.s"
.include "Online/Online.s"

.ifdef SATS_ARENA
backupall
# Online uses a small native text menu instead of Slippi's textured choices.
lwz r4, 0x2C(r3)
lbz r5, 0(r4)
cmpwi r5, 8
bne ARENA_HIDE_MENU_DONE
lwz r5, 0xAC(r4)
cmpwi r5, 0
beq ARENA_HIDE_MENU_MODEL
# Move the old description out of view; native updates reset its hidden flag.
lis r6, 0x461C
stw r6, 0(r5)
ARENA_HIDE_MENU_MODEL:
lwz r3, 0x28(r3)
li r4, 0x10
branchl r12, JObj_SetFlagsAll
ARENA_HIDE_MENU_DONE:
restoreall
.endif
mflr r0
