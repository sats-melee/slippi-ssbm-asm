# Sats Arena local funding gate and damage-credit diagnostics

Opt-in **NTSC-U Melee 1.02 only**. `build-arena.sh` derives a private build config
from `netplay.json`, defines `SATS_ARENA`, and generates
`Output/Arena/GALE01r2.ini`. Ordinary netplay, console and playback builds do not
include the hook or enlarge the recording-data buffer.

The hook at `0x8003EB30` observes Melee's explicit nominal damage-credit call.
It preserves GPRs, LR and CR, leaves FPRs/CTR/XER alone, and re-executes the
displaced `mflr r0`. It never changes the original arguments or game statistics.
The entry instruction must be verified against the target ISO before deployment.

Only local `SCENE_VERSUS_IN_GAME` captures/sends data. Online, replay, and other
scenes do not. The existing frame-start procedure zeroes a fixed-capacity buffer
each frame. The hook appends at most 32 records; excess sets an overflow flag.
The existing flush procedure appends one private batch after ordinary frame data
and **before** its frame bookend, using the same EXI transfer. The transfer buffer
reserves an extra 392 bytes. Frame-start invalidation therefore precedes credit
batch replacement. EXI strips this private command before recording/forwarding;
no new data is added to replay files or the public replay command table.

## Private EXI message (big endian, fixed 392 bytes)

| Offset | Field |
| --- | --- |
| 0 | Command `0xE6` |
| 1 | Protocol version `1` |
| 2 | Record count `0..32` |
| 3 | Flags: bit 0 means capture overflow; other bits reserved |
| 4 | Signed replay frame number |
| 8 + 12*i | Attacker port index `u8`, zero based |
| 9 + 12*i | Attacker follower flag `u8` |
| 10 + 12*i | Victim port index `u8` |
| 11 + 12*i | Victim follower flag `u8` |
| 12 + 12*i | Attack ID `u32` |
| 16 + 12*i | Nominal credited damage `f32` |

Unused records are zeroed, empty batches are sent, and ordinal is the record's
index within its frame. The matching emulator must validate/drop this command
explicitly, **never forward it to files, spectators, or reporting**. Do not use
this codeset with an unmodified emulator.

This is not a public Slippi event allocation. The emulator gates interpretation
to local 2–4 participant FFA/team matches and publishes only finalized batches.
Future rollback support must reset/restore this buffer each resimulation and
replace entire pending batches (including empty ones); it is intentionally not
enabled for online play.

Game credit and applied damage can differ for armor, invulnerability, throws,
followers and the percent cap. Records retain follower and attack identities.
They are diagnostic observations, not financial authorization or remote proof.

## Character-select funding gate

`PaymentGate.asm` injects at `0x80263250` (verified original instruction
`880DB652`, `lbz r0,-0x49ae(r13)`). This runs immediately after
`fn_80262F44` updates the PRESS START prompt and before the existing input
handler at `0x80263258`. It preserves GPRs, CR, CTR, XER and LR, using a
32-byte-aligned stack buffer for synchronous EXI. No live floating-point
values remain at this point in the function.

Only local Versus CSS calls the bridge. Protocol v2 reports all four slots,
including CPU slots and live team assignments. The private query is 20 bytes:

| Offset | Field |
| --- | --- |
| 0 | Command `0xE7` |
| 1 | Version `2` |
| 2 | Prompt ready, 0 or 1 (including teams) |
| 3 | Start trigger with input cooldown clear, 0 or 1 |
| 4–7 | P1–P4 slot kinds (human=0, CPU=1, closed=3) |
| 8–11 | P1–P4 character-select icon IDs |
| 12 | Teams enabled, 0 or 1 |
| 13–16 | P1–P4 team IDs: red=0, blue=1, green=2; 255 for closed/FFA |
| 17–19 | Reserved, always zero |

The CSSDoor.team field is +0x0A in the 0x24-byte door at 0x803F0DFC.
CSSData.vs.start.rules.is_teams is +0x18 from the CSSData pointer.
Team assignments are read on every query, before match entry. A mode, roster,
character, or team change revokes prior authorization. The matching host binds this roster to human funding and team settlement.
The CSS-load reset uses the same v2 size with non-ready invalid slot kinds.
Old/truncated packets fail closed and revoke any previous grant.

Dolphin replies with exactly one byte: 1 allows the latched Start; all other
values block it. Missing replies default to denial. The request never enters
replay command registration, replay files, spectators, or peer traffic.

The existing SceneLoadCSS hook also sends a non-ready reset query on every
local CSS entry. This invalidates stage-select admission even if players
return with identical characters. The host correlates asynchronous funding
admission with a selection generation. Once admitted, the hook replays the
queued Start; vanilla Melee performs its normal transition into stage select.

Reference for the matched CSS function and data layout:
https://github.com/doldecomp/melee/blob/master/src/melee/mn/mncharsel.c
and `src/melee/mn/types.h`. The validator checks actual target DOL instructions
rather than trusting the reference source alone.


## Private authoritative result summary

`Arena/SendResult.s` extends the existing `Recording/SendGameEnd.asm` injection
at `0x8016D884`; it introduces no second hook at that address. After the existing
`CreateMatchEndData` call populates results, and before ordinary Slippi `0x39`
is sent, local Versus emits this fixed 16-byte private message:

| Offset | Field |
| --- | --- |
| 0 | Command `0xE8` |
| 1 | Version `1` |
| 2 | MatchEnd outcome (normal timeout/stocks/stamina = 1/2/3) |
| 3 | Teams enabled, 0 or 1 |
| 4 | Active P1–P4 bit mask |
| 5 | Winning P1–P4 bit mask; zero if ambiguous or no contest |
| 6 | Winning team 0/1/2; 255 for FFA or no winner |
| 7 | Reserved zero |
| 8–11 | P1–P4 slot kinds (human=0, CPU=1, closed=3) |
| 12–15 | Team IDs; 255 for FFA/closed |

Teams use the unique active **team** with `is_small_loser == 0`, and include
all members of that team, even eliminated teammates and CPUs. Individual ranks
cannot substitute for a team's aggregate stock/timeout result. FFA requires a
unique rank-zero participant. Tied results, incomplete/invalid standings,
unsupported team IDs and no contest report no winner. The host must also match
the result roster against the paid/start roster and await the ordinary `0x39`
with the same outcome before using it. It must strip E8 from replay/spectator
traffic, like E6/E7.

The target `MatchEnd` is at `0x80479DA4`, player standings at +0x58 with stride
0xA8, and team standings at **+0x1C** with stride 0x0C. The decomp source's
+0x1B comment misses alignment padding. Actual NTSC-U 1.02 instructions in
`gm_801654A0` read team rank at +0x25 and active at +0x26; the validator checks
those exact loads as well as the original game-end injection instruction.

`Arena/test-result.sh` executes the actual PPC sender under QEMU. Fixtures
cover FFA/CPU winners, stocks, timeout, eliminated winning teammates, tied
standings, no contest and invalid fields, along with register/CR/CTR/XER
preservation and online/replay exclusion. These fixtures test the transport and
result interpretation; actual game-end data must also be tested in the launcher.
