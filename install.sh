#!/usr/bin/env bash
# agentbox installer — v3.2.0 (version stamp only: this always pulls the latest agentbox from main).
#   curl -fsSL https://raw.githubusercontent.com/harryngai/agentbox/main/install.sh | bash
# Downloads the agentbox script, makes it executable, and links `agentbox` + `ab` onto your PATH.
# Safe to re-run any time — it just pulls the latest version (so this doubles as an updater).
#
# Android/Termux + proot-distro only. No root needed.
# Override the source or install path with env vars:
#   AGENTBOX_BASE=<raw base url>   (default: the GitHub repo below — point it at your fork/host)
#   AGENTBOX_URL=<direct url to agentbox>
#   AGENTBOX_BIN=<where to put the real script>   (default: ~/.local/share/agentbox/agentbox)
set -euo pipefail

BASE="${AGENTBOX_BASE:-https://raw.githubusercontent.com/harryngai/agentbox/main}"
URL="${AGENTBOX_URL:-$BASE/agentbox}"
# The real script lives in the XDG data dir; agentbox/ab symlink to it from PATH. (config/state are separate XDG dirs.)
DEST="${AGENTBOX_BIN:-${XDG_DATA_HOME:-$HOME/.local/share}/agentbox/agentbox}"

say(){ printf '\033[32m%s\033[0m\n' "$*"; }
err(){ printf '\033[31m%s\033[0m\n' "$*" >&2; }

fetch(){ if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else err "need curl or wget to download"; exit 1; fi; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
say "downloading agentbox from $URL"
fetch "$URL" "$tmp" || { err "download failed — check the URL / network (private repo?)"; exit 1; }

# Sanity: reject a 404 page or a wrong URL — the file must look like the agentbox script (bash shebang + a bare VERSION= line).
if ! { head -1 "$tmp" | grep -q '^#!.*bash'; } || ! grep -q '^VERSION=' "$tmp"; then
  err "the downloaded file does not look like agentbox — aborting (bad URL, or a 404/HTML page?)"
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
mv "$tmp" "$DEST"; trap - EXIT
chmod +x "$DEST"
say "installed → $DEST"

# link agentbox + ab onto PATH (Termux: $PREFIX/bin; else ~/.local/bin). agentbox has no --install command — setup's
# 'links' step re-links idempotently, but the installer creates them up front so `ab` works before the guided setup.
if [ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ]; then BIN="$PREFIX/bin"; else BIN="$HOME/.local/bin"; fi
mkdir -p "$BIN"
ln -sf "$DEST" "$BIN/agentbox"; ln -sf "$DEST" "$BIN/ab"
say "linked $BIN/{agentbox,ab} → $DEST"
case ":$PATH:" in *":$BIN:"*) :;; *) [ -n "${PREFIX:-}" ] || say "note: add ~/.local/bin to PATH → echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc";; esac

# One-time cleanup: older installs put the real script at ~/agentbox; it now lives under ~/.local/share/agentbox.
# The agentbox/ab links were just repointed to $DEST above, so the old file is a harmless stray — remove it.
OLD="$HOME/agentbox"
if [ "$DEST" != "$OLD" ] && [ -f "$OLD" ] && [ ! -L "$OLD" ]; then
  rm -f "$OLD" && say "removed the old real script at $OLD (agentbox/ab now point to $DEST)"
fi

# Ship the box-profile templates next to the script (XDG data dir). `ab <name>` copies one into ~/.config/agentbox
# on first use. Re-running install.sh refreshes these pristine templates without touching your edited copies in ~/.config.
TPLDIR="$(dirname "$DEST")/templates"
mkdir -p "$TPLDIR"
tpl_ok=1
for t in claude codex copilot shell web; do
  if fetch "$BASE/templates/$t.conf" "$TPLDIR/$t.conf" \
     && head -1 "$TPLDIR/$t.conf" | grep -q '^# agentbox box profile'; then :
  else err "  template '$t' failed or looks wrong (404/HTML?)"; rm -f "$TPLDIR/$t.conf"; tpl_ok=; fi
done
if [ -n "$tpl_ok" ]; then say "templates → $TPLDIR"; else err "some templates failed — re-run install.sh when the network is back"; fi

printf '\n'
say "done — $(bash "$DEST" version 2>/dev/null || echo agentbox)"

# ── Guided first-time setup ────────────────────────────────────────────────────
# Delegate to `ab setup` (defined in agentbox: links → Termux init → tmux → unkill → tokens).
# This script arrives over a pipe (curl | bash), so hand the child its tty via /dev/tty.
if [ -t 1 ] && [ -r /dev/tty ]; then
  printf '\n'; say "agentbox is installed — starting guided setup."
  bash "$DEST" setup < /dev/tty
else
  say "No interactive terminal — when ready, run the guided setup yourself:"
  say "  ab setup      walks through every step (links · Termux · tmux · unkill · tokens)"
fi
