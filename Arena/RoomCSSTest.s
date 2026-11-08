# Execute the actual online CSS hook with a mocked match-state transfer.
.include "Common/Common.s"
.include "Online/Online.s"
.set FN_LoadMatchState, MockLoad

.section .text
.global _start
_start:
load r13, 0x804e0000
load r20, 0x80410000
load r21, 0x80411000
load r8, CSSDT_BUF_ADDR
stw r20, 0(r8)
stw r21, CSSDT_MSRB_ADDR(r20)
load r8, 0x80479d30
load r9, 0x08000000 # Online CSS
stw r9, 0(r8)
li r9, MM_STATE_CONNECTION_SUCCESS
stb r9, MSRB_CONNECTION_STATE(r21)
li r9, ONLINE_MODE_UNRANKED
stb r9, OFST_R13_ONLINE_MODE(r13)
bl Hook
lbz r9, OFST_R13_ONLINE_MODE(r13)
cmpwi r9, ONLINE_MODE_DIRECT
bne Failed

# Every local slot uses its own immutable team, including blue and green.
li r9, 1
stb r9, MSRB_GAME_INFO_BLOCK + 0x8(r21)
li r9, 0
stb r9, MSRB_GAME_INFO_BLOCK + 0x69(r21)
li r9, 1
stb r9, MSRB_GAME_INFO_BLOCK + 0x69 + 0x24(r21)
li r9, 2
stb r9, MSRB_GAME_INFO_BLOCK + 0x69 + 0x48(r21)
stb r9, MSRB_GAME_INFO_BLOCK + 0x69 + 0x6c(r21)
li r22, 0
TeamLoop:
stb r22, MSRB_LOCAL_PLAYER_INDEX(r21)
bl Hook
lbz r9, OFST_R13_ONLINE_MODE(r13)
cmpwi r9, ONLINE_MODE_TEAMS
bne Failed
lbz r9, CSSDT_TEAM_IDX(r20)
addi r10, r22, 1
cmpwi r10, 4
bne ExpectedTeam
li r10, 3
ExpectedTeam:
cmpw r9, r10
bne Failed
addi r22, r22, 1
cmpwi r22, 4
blt TeamLoop

# A new FFA room clears teams mode; an unconnected CSS preserves menu choice.
li r9, 0
stb r9, MSRB_GAME_INFO_BLOCK + 0x8(r21)
bl Hook
lbz r9, OFST_R13_ONLINE_MODE(r13)
cmpwi r9, ONLINE_MODE_DIRECT
bne Failed
li r9, MM_STATE_IDLE
stb r9, MSRB_CONNECTION_STATE(r21)
li r9, ONLINE_MODE_UNRANKED
stb r9, OFST_R13_ONLINE_MODE(r13)
bl Hook
lbz r9, OFST_R13_ONLINE_MODE(r13)
cmpwi r9, ONLINE_MODE_UNRANKED
bne Failed

# The local Versus CSS never reads or changes room settings.
load r8, 0x80479d30
load r9, 0x02000000
stw r9, 0(r8)
li r9, MM_STATE_CONNECTION_SUCCESS
stb r9, MSRB_CONNECTION_STATE(r21)
bl Hook
lbz r9, OFST_R13_ONLINE_MODE(r13)
cmpwi r9, ONLINE_MODE_UNRANKED
bne Failed
li r3, 0
b TestExit
Failed:
li r3, 1
TestExit:
li r0, 1
sc

MockLoad:
blr
Hook:
backup
.include "Online/Menus/CSS/FetchMatchInfo.asm"
restore
blr

.section .bss
.space 0x500000
