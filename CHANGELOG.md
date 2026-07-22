# Changelog

All notable changes to **agentbox**, newest first.

Versioning is `major.normal.minor`:
- **major** — breaking change
- **normal** — new feature/behaviour (resets minor to 0)
- **minor** — fix, hardening, or wording

`ab update` always pulls the latest from `main`, so `ab version` is the source of truth for what's deployed. Each box template also carries its own `# template-version:` stamp, bumped whenever that template's file changes; `ab` warns when your `~/.config/agentbox/box-<name>.conf` copy is behind the shipped template.

## 3.14.2
- **Fix a regression from 3.14.0:** the `--kill-on-exit` flag added to the desktop `proot-distro login` isn't accepted by proot-distro's `login`, so the desktop exited immediately ("box desktop exited immediately"). Reverted it. The original goal — killing the daemonised `Xvnc`/`chromium`/`mitmweb` that outlive the tmux session — is now done directly via `boxkillprocs`: it kills any process whose executable resolves inside the box rootfs (`/proc/<pid>/exe`), used by both `ab stop` and box deletion. Version-independent, no reliance on a proot-distro flag.

## 3.14.1
- Desktop stop hints now point at `ab stop` (close, keep the box) instead of `ab remove` — the old "already running, stop it: ab remove <name>" even named the wrong box (the one you were launching, not the one running). Desktops stay one-at-a-time by design; switch with `ab stop` then `ab <other>`.

## 3.14.0
- **Desktop boxes no longer leak / lock up.** The desktop `proot-distro login` now runs with `--kill-on-exit`, so stopping it cleanly kills `Xvnc`/`chromium`/`mitmweb` instead of leaving orphans that hold the container "busy" (which had made `agentbox-web` un-removable and un-rebuildable). `aboxdrop` also force-kills any leftover procs before removing.
- **`web` is no longer throwaway** (`EPHEMERAL=0`) — it builds once and reuses the box, so `ab web` doesn't re-download the desktop every launch. Rebuild fresh with `ab remove web`.
- **New `ab stop`** — closes the running box desktop but keeps the box (instant reopen). `ab remove <name>` is still the delete-and-rebuild path.

## 3.13.0
- Profiles now live at `~/.config/agentbox/profile/<name>.conf` — no `box-` prefix, same filename as the template. Existing `box-<name>.conf` files are migrated automatically on the next `ab` run. (Snapshots stay `box-snapshot-<name>.tar.gz`.)

## 3.12.1
- **Critical fix:** `ab <name>` seeded *every* first-time non-claude box from the built-in claude default instead of the real template — so `ab web`, `ab run`, `ab codex`, etc. all opened a claude box. Cause: a bash pitfall in `aboxdefault` where a single `local path=… name=… src="$TPL/$name.conf"` expanded `$name` before it was assigned, making `src` always `$TPL/.conf` (missing). The v3.10.0 fallback warning is what finally surfaced it.

## 3.12.0
- **Colour in every box** — boxes now get a colourful interactive shell: `ls`/`grep`/`ll` coloured, a colour prompt, and `TERM` defaulted to `xterm-256color`. Written into the rootfs host-side at launch (idempotent), so existing boxes get colour on their next launch — no rebuild needed. `TERM` is also exported into the box so the agent/`RUN` process renders colour too.
- **Template versions reconciled** — all shipped templates are stamped `3.12.0`; a template's stamp now bumps whenever its file changes (not only on new options). The "your copy is behind" note is worded neutrally ("it changed since, worth a look").
- Added this `CHANGELOG.md`.

## 3.11.3
- Help: the Templates section shows the key app/desktop each box runs, not its token names.

## 3.11.2
- Help: a `<placeholder>` / `[arg]` name token renders yellow (it isn't a literal command); literal commands like `save`/`pkg` stay bold.

## 3.11.1
- Session picker is an aligned, coloured table with each session's created date/time (num · name · created · folder).
- Help: `<name> [cmd]` gets the yellow `[cmd]` arg like other rows; the long `session` row is split into two lines.

## 3.11.0
- `ab session` lists **every** tmux session, not just `ab-*` — fixes legacy un-prefixed sessions (e.g. an old `sync-all`) and your own sessions being invisible. `ab session kill <name>` matches a bare or `ab-`-prefixed name.
- Help: added a Templates section showing each template's version + key info.

## 3.10.0
- Templates: friendlier comments (identity marker on line 1 preserved).
- Built-in fallback profile is now identical to the `claude` template.
- New complex-mode `desktop` template — full Ubuntu xfce + Mesa/Vulkan GPU stack (honest best-effort accel on unrooted Android).
- `ab` warns loudly when a box falls back to the built-in claude default, so `ab web → claude` can't happen silently.

## 3.9.1
- Template `web` drops `git` too — a browsing box needs no dev toolchain (empty `PKGS`; xfce + chromium come from `DESKTOP`).

## 3.9.0
- Templates: inject `GH_TOKEN` wherever `gh` ships.
- Renamed `shell` → `run` (installs claude, opens a shell).
- Standardised the `#DIST=debian` hint; `web` now binds cwd + `MITM` on.
- `install.sh` prunes orphaned templates on update.

## 3.8.0
- Version-stamp each template (`# template-version:`); `ab update` lists the versions it installs; `ab` warns when your `box-<name>.conf` falls behind its template.

## 3.7.0
- `ab session host-<name>` (or `ab host-<name>`) opens a plain **host** shell — no box, no proot — still an `ab-*` session that lists/kills/wakelocks the same; an optional command runs in it.

## 3.6.0
- Help screen: banner-first layout with inline status, adaptive (phone-friendly) width, `·` separators, point-form notes, trimmed descriptions.

## 3.5.0
- `ab <name>` opens a fresh tmux session each launch (`ab-<box>-<folder>-<rand>`), surviving ssh-drop; reattach earlier ones via `ab session`.

## 3.4.1
- `ab <name> -n/--new` opens an extra session in the same folder (default still re-attaches).

## 3.4.0
- `ab sync watch` with no path watches every recorded pair in one `sync-all` session.

## 3.3.3
- Sync: show the full remote path (`dropbox:<path>`) in the confirm prompt.

## 3.3.2
- `ab update` refreshes code only — skips the guided setup.

## 3.3.1
- `ab update` just re-runs the installer (dropped the SHA-pin dance).

## 3.3.0
- SHA-pin `ab update` to bypass the raw-CDN cache (later superseded by 3.3.1).

## 3.2.2
- Sync: remove a pair from any folder; accept a `dropbox:` prefix.

## 3.2.1
- Setup: auto-skip the links step when already on `PATH`.

## 3.2.0 (and earlier)
- Initial tracked history: box build hardening (dpkg recovery, self-contained `gh` install, non-apt arch fallback), default `DIST=debian` when a profile leaves it empty, `ab remove` prompts to delete the profile conf, and `gh`/`git`/`curl` shipped in every profile.
