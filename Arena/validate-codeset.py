#!/usr/bin/env python3
"""Validate the target ROM and generated hook, then emit non-secret build provenance."""
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
iso = Path(sys.argv[1])
with iso.open('rb') as f:
    header = f.read(8)
    if header[:6] != b'GALE01' or header[7] != 2:
        raise SystemExit('Arena hook requires NTSC-U GALE01 revision 2 (Melee 1.02).')
    f.seek(0x420)
    dol_offset = struct.unpack('>I', f.read(4))[0]
    f.seek(dol_offset)
    dol = f.read(0x100)
    offsets = struct.unpack_from('>7I', dol, 0)
    addresses = struct.unpack_from('>7I', dol, 0x48)
    sizes = struct.unpack_from('>7I', dol, 0x90)
    for hook, expected in [(0x80263250, '880db652'), (0x8026699c, '900db638'),
                           (0x8003eb30, '7c0802a690010004')]:
        for offset, address, size in zip(offsets, addresses, sizes):
            if address <= hook < address + size:
                f.seek(dol_offset + offset + hook - address)
                if f.read(len(expected) // 2).hex() != expected:
                    raise SystemExit(f'Unexpected instruction at {hook:08x}; do not install.')
                break
        else:
            raise SystemExit(f'Hook {hook:08x} was not found in DOL.')

output = root / 'Output/Arena/GALE01r2.ini'
text = output.read_text()
if len(re.findall(r'^C203EB30 ', text, re.M)) != 1:
    raise SystemExit('Expected exactly one damage-credit hook at 0x8003eb30.')
if '$Arena: Local damage-credit diagnostics\n' not in text:
    raise SystemExit('Diagnostic hook is not enabled in the generated output.')
if len(re.findall(r'^C2263250 ', text, re.M)) != 1:
    raise SystemExit('Expected exactly one CSS payment hook at 0x80263250.')
if len(re.findall(r'^C226699C ', text, re.M)) != 1:
    raise SystemExit('Expected exactly one CSS-load reset hook at 0x8026699c.')
sources = ['Arena/PaymentGate.asm', 'Online/Menus/CSS/SceneLoadCSS.asm',
           'Arena/CaptureCredit.asm', 'Recording/Recording.s', 'Recording/SendFrameStart.s',
           'Recording/FlushFrameBuffer.asm', 'build-arena.sh']
manifest = {
    'format': 1, 'protocol': 1, 'command': '0xE6', 'packet_bytes': 392,
    'game': 'GALE01r2', 'mode': 'local VS diagnostics only', 'entry': '0x8003EB30',
    'expected_prologue': '7c0802a690010004',
    'asm_base_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
    'gecko_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root / 'build-tools/gecko-src', text=True).strip(),
    'source_sha256': {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in sources},
    'codeset_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
    'not_for_settlement': True,
    'payment_gate': {'command': '0xE7', 'request_bytes': 12, 'response_bytes': 1,
                     'entry': '0x80263250', 'expected_instruction': '880db652',
                     'reset_entry': '0x8026699C', 'reset_instruction': '900db638'},
}
(output.parent / 'arena-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('PASS: NTSC-U 1.02 credit/CSS/reset instructions, unique enabled hooks, codeset provenance')
