#!/usr/bin/env bash
# agentbox installer — v3.11.0 (version stamp only: this always pulls the latest agentbox from main).
#   curl -fsSL https://raw.githubusercontent.com/harryngai/agentbox/main/install.sh | bash
# Downloads the agentbox script, makes it executable, and links `agentbox` + `ab` onto your PATH.
# Safe to re-run any time — it just pulls the latest version (so this doubles as an updater).
#
# Android/Termux + proot-distro only. No root needed.
# Override the source or install path with env vars:
#   AGENTBOX_BASE=<raw base url>   (default: the GitHub repo below — point it at your fork/host)
#   AGENTBOX_URL=<direct url to agentbox>
#   AGENTBOX_BIN=<where to put the real script>   (default: ~/.local/share/agentbox/agentbox)
#   AGENTBOX_SKIP_SETUP=1   refresh code+templates only, skip the guided setup (what `ab update` passes)
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
TEMPLATES="claude codex copilot run web desktop"
tpl_ok=1; tpls=
for t in $TEMPLATES; do
  if fetch "$BASE/templates/$t.conf" "$TPLDIR/$t.conf" \
     && head -1 "$TPLDIR/$t.conf" | grep -q '^# agentbox box profile'; then
    v=$(sed -n 's/^# *template-version:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$TPLDIR/$t.conf" | head -1)
    tpls="${tpls:+$tpls, }$t ${v:-?}"
  else err "  template '$t' failed or looks wrong (404/HTML?)"; rm -f "$TPLDIR/$t.conf"; tpl_ok=; fi
done
# Prune orphaned pristine templates (e.g. one renamed/removed upstream, like shell→run) so `ab <name>` only offers the
# current set. Guarded on tpl_ok so a failed fetch can't wipe the dir. Your edited copies in ~/.config are never touched.
if [ -n "$tpl_ok" ]; then
  for f in "$TPLDIR"/*.conf; do [ -e "$f" ] || break; b=$(basename "$f" .conf)
    case " $TEMPLATES " in *" $b "*) :;; *) rm -f "$f" && say "  pruned old template: $b";; esac
  done
fi
if [ -n "$tpl_ok" ]; then say "templates → $TPLDIR  ($tpls)"; else err "some templates failed — re-run install.sh when the network is back"; fi

printf '\n'
say "done — $(bash "$DEST" version 2>/dev/null || echo agentbox)"

# ── Guided first-time setup ────────────────────────────────────────────────────
# Delegate to `ab setup` (defined in agentbox: links → Termux init → tmux → unkill → tokens).
# This script arrives over a pipe (curl | bash), so hand the child its tty via /dev/tty.
# `ab update` sets AGENTBOX_SKIP_SETUP=1 so an update refreshes code only and never re-walks setup.
if [ -n "${AGENTBOX_SKIP_SETUP:-}" ]; then
  printf '\n'; say "updated — config left untouched. Run 'ab setup' to (re)configure the environment."
elif [ -t 1 ] && [ -r /dev/tty ]; then
  printf '\n'; say "agentbox is installed — starting guided setup."
  bash "$DEST" setup < /dev/tty
else
  say "No interactive terminal — when ready, run the guided setup yourself:"
  say "  ab setup      walks through every step (links · Termux · tmux · unkill · tokens)"
fi
