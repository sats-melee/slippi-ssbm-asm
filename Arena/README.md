# Sats Arena local damage-credit diagnostics

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
to local, two-player, non-team matches and publishes only finalized batches.
Future rollback support must reset/restore this buffer each resimulation and
replace entire pending batches (including empty ones); it is intentionally not
enabled for online play.

Game credit and applied damage can differ for armor, invulnerability, throws,
followers and the percent cap. Records retain follower and attack identities.
They are diagnostic observations, not financial authorization or remote proof.
