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
    for offset, address, size in zip(offsets, addresses, sizes):
        if address <= 0x8003eb30 < address + size:
            f.seek(dol_offset + offset + 0x8003eb30 - address)
            if f.read(8) != bytes.fromhex('7c0802a690010004'):
                raise SystemExit('Unexpected damage-credit prologue; do not install this hook.')
            break
    else:
        raise SystemExit('Damage-credit routine was not found in DOL text sections.')

output = root / 'Output/Arena/GALE01r2.ini'
text = output.read_text()
if len(re.findall(r'^C203EB30 ', text, re.M)) != 1:
    raise SystemExit('Expected exactly one damage-credit hook at 0x8003eb30.')
if '$Arena: Local damage-credit diagnostics\n' not in text:
    raise SystemExit('Diagnostic hook is not enabled in the generated output.')
sources = ['Arena/CaptureCredit.asm', 'Recording/Recording.s', 'Recording/SendFrameStart.s',
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
}
(output.parent / 'arena-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('PASS: NTSC-U 1.02 prologue, unique enabled hook, generated codeset provenance')
