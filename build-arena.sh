#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
export PATH="$ROOT/build-tools/bin:$PATH"

# Derive from upstream without editing its output paths, defaults, or console codes.
python3 - <<'PY'
import json
from pathlib import Path
config = json.loads(Path('netplay.json').read_text())
config['outputFiles'] = config['outputFiles'][:1]  # This hook is verified for NTSC-U 1.02 only.
output = config['outputFiles'][0]
output['file'] = 'Output/Arena/GALE01r2.ini'
header = output['header']
header.insert(header.index('[Gecko_Enabled]') + 1, '$Arena: Local damage-credit diagnostics')
config['codes'].append({
    'name': 'Arena: Local damage-credit diagnostics',
    'authors': ['Sats Arena contributors'],
    'description': ['Local VS diagnostic only. Nominal game credit is NOT actual applied percent.'],
    'build': [{'type': 'injectFolder', 'sourceFolder': 'Arena', 'isRecursive': False}],
})
Path('arena.generated.json').write_text(json.dumps(config, indent=2) + '\n')
PY
gecko build -cache -defsym "STG_EXIIndex=1,SATS_ARENA=1" -c arena.generated.json
