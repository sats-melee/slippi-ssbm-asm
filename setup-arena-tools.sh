#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Run inside the existing Ubuntu build container. No SteamOS root changes.
sudo apt-get install -y golang-go binutils-powerpc-linux-gnu qemu-user
mkdir -p "$ROOT/build-tools/bin"
if [[ ! -d "$ROOT/build-tools/gecko-src/.git" ]]; then
  git clone https://github.com/JLaferri/gecko.git "$ROOT/build-tools/gecko-src"
fi
git -C "$ROOT/build-tools/gecko-src" checkout edba7fd9efcd5a4df753aee7a938cb2ff6604690
cd "$ROOT/build-tools/gecko-src"
GOCACHE="$ROOT/build-tools/go-cache" GOPATH="$ROOT/build-tools/go" \
  go build -o "$ROOT/build-tools/bin/gecko" .
for tool in as objcopy nm; do
  ln -sf "/usr/bin/powerpc-linux-gnu-$tool" "$ROOT/build-tools/bin/powerpc-eabi-$tool"
done
