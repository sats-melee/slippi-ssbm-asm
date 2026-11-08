################################################################################
# Address: 0x80260310 # Start of CSS_BigFunc...
################################################################################

.include "Common/Common.s"
.include "Online/Online.s"

# Ensure that this is an online CSS
getMinorMajor r3
cmpwi r3, SCENE_ONLINE_CSS
bne EXIT # If not online CSS, continue as normal

# load MSRB address and get match state info
loadwz r3, CSSDT_BUF_ADDR
lwz r3, CSSDT_MSRB_ADDR(r3)
branchl r12, FN_LoadMatchState
.ifdef SATS_ARENA
# The server's immutable room roster owns FFA/teams and each player's team.
loadwz r3, CSSDT_BUF_ADDR
lwz r4, CSSDT_MSRB_ADDR(r3)
lbz r5, MSRB_CONNECTION_STATE(r4)
cmpwi r5, MM_STATE_CONNECTION_SUCCESS
bne ARENA_ROOM_NOT_CONNECTED
lbz r5, MSRB_GAME_INFO_BLOCK + 0x8(r4)
cmpwi r5, 1
li r5, ONLINE_MODE_DIRECT
bne ARENA_ROOM_STORE_MODE
li r5, ONLINE_MODE_TEAMS
lbz r6, MSRB_LOCAL_PLAYER_INDEX(r4)
cmplwi r6, 3
bgt ARENA_ROOM_NOT_CONNECTED
mulli r6, r6, 0x24
addi r6, r6, MSRB_GAME_INFO_BLOCK + 0x69
lbzx r6, r4, r6
cmplwi r6, 2
bgt ARENA_ROOM_NOT_CONNECTED
addi r6, r6, 1
stb r6, CSSDT_TEAM_IDX(r3)
ARENA_ROOM_STORE_MODE:
stb r5, OFST_R13_ONLINE_MODE(r13)
ARENA_ROOM_NOT_CONNECTED:
.endif

EXIT:
# Handle replaced code line
li r0, 0
