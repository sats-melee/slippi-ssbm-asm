#!/usr/bin/env python3
"""Small source-contract check for the Arena-only room menu patches."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
assert (root / 'Arena/ArenaRoomMenu.asm').is_file()
assert not (root / 'Online/Menus/TitleMenu/ArenaRoomMenu.asm').exists()
menu = (root / 'Online/Menus/TitleMenu/OnMenuPrep.asm').read_text()
constants = (root / 'Online/Online.s').read_text()
entry = (root / 'Online/Menus/CSS/TextEntryScreen/CheckTriggersAndZ.asm').read_text()
status = (root / 'Online/Menus/CSS/FetchMatchInfo.asm').read_text()
team_button = (root / 'Online/Menus/CSS/Teams/InitTeamToggleButton.asm').read_text()
assert '.set ONLINE_SUBMENU_OPTION_COUNT, 2' in constants
assert '.set OPTION_UNRANKED_IDX, 0' in constants
assert '.set OPTION_DIRECT_IDX, 1' in constants
assert '.byte ONLINE_SUBMENU_OPTION_COUNT' in menu
assert '.string "Create Room"' in menu and '.string "Join Room"' in menu
assert 'ARENA_MENU_REMOVE' in menu
assert entry.index('b FN_FetchSuggestion_Restore', entry.index('# Room codes')) < entry.index('CONST_SlippiCmdSendNameEntryIndex')
assert 'No suggestions exist in room mode' in entry
assert 'MSRB_GAME_INFO_BLOCK + 0x8' in status
assert 'li r5, ONLINE_MODE_DIRECT' in status and 'li r5, ONLINE_MODE_TEAMS' in status
assert 'MSRB_LOCAL_PLAYER_INDEX' in status and 'stb r6, CSSDT_TEAM_IDX' in status
assert '.ifdef SATS_ARENA\n# Teams are chosen by the host before room funding, never mutated by a peer.\nb EXIT' in team_button
print('PASS: two room choices, room-code entry without official autocomplete, canonical FFA/teams gameplay mode')
