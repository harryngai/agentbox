# Changelog

All notable changes to **agentbox**, newest first.

Versioning is `major.normal.minor`:
- **major** — breaking change
- **normal** — new feature/behaviour (resets minor to 0)
- **minor** — fix, hardening, or wording

`ab update` always pulls the latest from `main`, so `ab version` is the source of truth for what's deployed. Each box template also carries its own `# template-version:` stamp, bumped whenever that template's file changes; `ab` warns when your `~/.config/agentbox/box-<name>.conf` copy is behind the shipped template.

## 3.22.0
- **`ab ps` — everything agentbox has spawned, what it costs, and how to stop it.** One screen for "why is this phone hot?": a **live** CPU sample (each process's share of one core, measured over 2 s) beside its **lifetime** CPU and age, every row attributed to the box or host helper that owns it — box processes, the `proot` translator per box, the tmux sessions, the `GPU=virgl` server, the `sync watch` loop — with the wakelock state on top, since with the screen off that is what turns CPU into battery. Idle box children (an agent's own greps and gits) are folded into a count so the list stays readable; anything not agentbox's earns a row only by actually being busy. `AB_PS_SAMPLE=<sec>` changes the window.
- **It names strays: box processes that outlived their box, which nothing else on the phone can stop.** A desktop daemonises Xvnc/x11vnc/chromium/dbus on purpose, so they legitimately sit at `ppid 1` — but only while `ab-boxgui` lives. Once it doesn't, they are invisible to `ab session`, `ab stop` reports no desktop, and they keep running until you reboot. The judgement is made **per box, not per process**: an orphan is only a stray when nothing else in that box is still owned by a session or the running desktop, so a box you are actively using is never accused. **`ab ps kill`** clears exactly those (plus a `GPU=virgl` server with no desktop, plus a wakelock no session is holding) after showing you the list and asking; `ab ps kill <pid…>` accepts only pids from that list. Boxes, sessions and desktops are never touched.
- **Fixed: `boxkillprocs` has never killed anything, so daemonised desktop processes survived every `ab stop`, `ab remove` and `ab rebuild`** (3.14.2, where it was introduced as the fix for exactly that). It matched `/proc/<pid>/exe` against the box rootfs, but proot execs every guest binary through `$PREFIX/libexec/proot/loader`, so a box process's `exe` **is the loader** — never a path under the rootfs — and argv says nothing either (a box process shows on the host as a bare `dbus-daemon`). The reliable test is `/proc/<pid>/maps`: the guest binary and every library it loaded are mapped by their real host paths under the rootfs. Now one `grep` over maps answers "which box owns this pid" for the whole phone at once, shared by the killer and `ab ps`.
  - Found on hardware, not in review: an at-spi `dbus-daemon` from a closed `desktop` box, orphaned at `ppid 1`, **spinning 96% of one core for 10 hours** with a wakelock held — alongside five leaked `ssh-agent`s from the same dead box. `boxpids` finds all six; the old exe test found none.
  - `ab remove` / `ab rebuild` also stop failing with "container busy" when a box left daemons behind.
- Not mirrored to the Ubuntu Touch build (`agentbox-ut`) yet.

## 3.21.1
- **`desktop` template (v3.21.1): `RFB=1` is now on by default** instead of shipped commented out. The browser client is touch-absolute — the pointer lands under your finger — and a Plasma desktop is exactly the case where you want to *aim* a pointer, so the native-VNC door (127.0.0.1:5901, localhost, same password) is open from the first launch. Set `RFB=0` in your copy to close it. Unchanged elsewhere: `web` keeps it commented out, since a browsing box has no reason to carry an extra listener.

## 3.21.0
- **`DESKTOP=` now names a session, and `kde` is the new one: a full KDE Plasma desktop.** The value was previously a label nobody read — anything non-empty got the same minimal xfce. Now `DESKTOP=xfce` (unchanged: `xfce4-session` + `xfwm4`, no panel/thunar/goodies) or `DESKTOP=kde` (`plasma-desktop` + `plasma-workspace` + `kwin-x11` + `systemsettings` + `konsole` + `breeze`). Anything else still maps to xfce, so existing profiles build exactly as before.
  - **Plasma is installed *with* recommends** — deliberately the opposite of the xfce line beside it. A `--no-install-recommends` Plasma tends to come up half-dressed (missing icon themes, QML bits, integration), and a desktop that won't start is a far worse trade than a bigger download. Expect **~2 GB** on the first build; the launcher says so before it starts.
  - **The session gets what it needs to run under proot:** xfce4-session brings its own bus, Plasma does not, so `startplasma-x11` is wrapped in `dbus-run-session` (falling back to `dbus-launch --exit-with-session`). Without a GPU the launcher also sets `KWIN_COMPOSE=N` and `QT_QUICK_BACKEND=software` — on llvmpipe, compositing is the difference between a desktop and a slideshow. With `GPU=virgl` neither is set and you get the full effects; the launch summary states which of the two you're looking at, and where Plasma's log is, since a session that dies *after* Xvnc came up shows as a black screen rather than a failed launch.
  - **One definition of "which session"**: `desession()` is what the installer verifies and what the launcher execs, so "the stack installed" and "what we start" can't drift apart. Switching `DESKTOP=` on an already-built box is caught at launch — `box 'x' has no kde desktop stack (…) — rebuild it` — instead of opening a black desktop.
- **Templates:** `desktop` (v3.21.0) is now **Ubuntu + KDE Plasma** with dolphin · kate · ark · gwenview · okular · Plasma wallpapers on top, keeping its real (non-snap) Firefox, Mesa GL and `gpu <cmd>` wrapper; its GPU note now explains that Plasma is exactly where `GPU=virgl` shows. `web` (v3.21.0) stays xfce on purpose — for a browsing box that's the right size — and says so.

## 3.20.0
- **`RFB=1` profile option (desktop boxes) — the same desktop on a plain-VNC port, so a native viewer with a *trackpad* mode can drive it.** KasmVNC's browser client maps touch **absolutely**: the pointer lands under your finger, so there is no relative/trackpad mode, and upstream noVNC's request for one (#1764) is still open. The Android viewers that do have it — **AVNC** (Settings → Gesture style → Touchpad) and **bVNC** (Simulated Touchpad) — speak plain RFB, which KasmVNC deliberately does not: it "broke from the RFB specification" and answers its own web client only, so those apps could never reach a box desktop. `RFB=1` runs **x11vnc** alongside, attached to the **same X display `:1`**, exporting standard VNC on **5901**. One desktop, one session, one password, two doors: the browser on 6902 when absolute touch is fine, a trackpad-mode app on 5901 when it isn't.
  - **Same guard rails as the web client:** localhost-only unless `LAN=1`, and the password is whatever `ab pw <name>` set (or the random per-launch one). Classic VNC auth is a shared password with **no username**, DES over only its **first 8 characters** — the launch summary says so, because a 16-char password otherwise looks like the viewer truncated or rejected it. Under `LAN=1` the summary names that as the weaker door.
  - **Never opens an unauthenticated port:** if the password file didn't get written, x11vnc is not started at all. Verified on x11vnc 0.9.17 (Debian trixie/arm64): the port answers `RFB 003.008` and offers security type 2 (VncAuth) — never type 1 (None).
  - **The summary can't claim a port that isn't listening:** the in-box script writes an ok/fail marker that the host reads before printing. It confirms the daemon survived with `pgrep`, falling back to x11vnc's own exit status where `procps` isn't installed — a minimal Debian rootfs doesn't have it.
  - **Never costs you the desktop:** a failed x11vnc install (fetched on demand at **launch**, so desktop boxes built before this release pick it up without a rebuild), a port already in use, or a daemon that won't stay up — each degrades to web-only with a warning, and the desktop still opens. `ab stop` needs no change: it already kills everything running out of the rootfs.
- **Templates:** `desktop` (v3.20.0) and `web` (v3.20.0) ship `RFB=1` commented out, with the reason for it (the browser client is touch-absolute) written next to the switch.

## 3.19.0
- **`ab <name>` asks before creating a box it doesn't know.** An unknown name was both how you create a box and what a typo looks like — `ab clade` silently seeded a profile and started downloading a rootfs. Now it confirms first: `no box 'clade' yet — create it from the built-in default (a claude box)? [Y/n]`, with the names ab already knows (your profiles + shipped templates) printed above it so the typo is obvious. **Default is yes**, so the intended path is still one extra Enter; `n` (or `q`) cancels before anything is written or fetched. When the name matches a shipped template the known-names line is skipped and the question just says which template it will use.
  - Asks only when there is a terminal to ask on — piped/`cron`/non-interactive runs create as before, as does `AB_YES=1`. If the rootfs is already built and only the profile conf went missing, there is no question either (not a typo).
  - The `proot-distro` install check moved below the profile step, so a mistyped name can no longer trigger a package install on a fresh phone.
- Same change in the Ubuntu Touch build (`agentbox-ut` v3.19.0-ut), where the built-in profile names (`claude · codex · copilot · shell`) are part of the known-names list.

## 3.18.0
- **`GPU=virgl` profile option (desktop boxes) — real hardware GL in the KasmVNC desktop.** Until now a box desktop rendered entirely on the CPU (llvmpipe) and chromium ran with `--disable-gpu`. The obvious fix — Mesa's Adreno Vulkan driver (turnip) inside the box — does not work on unrooted Android: distro Mesa builds turnip against the **MSM DRM** interface, but Android exposes the GPU as `/dev/kgsl-3d0` and blocks `/dev/dri`, so turnip enumerates no device at all (verified on an Adreno 830: `vulkaninfo` → `ERROR_INITIALIZATION_FAILED`, only llvmpipe). `GPU=virgl` takes the other route: a **virgl vtest server on the Termux side**, where Android's own GL driver is available, and the box talks to it over ONE unix socket with `GALLIUM_DRIVER=virpipe`. Rendering lands on the GPU; frames still present through X shm, so KasmVNC, `LAN=1`, `ab pw` and the whole browser-access model are unchanged. Measured on an Adreno 830 (Snapdragon 8 Elite), which upstream turnip cannot drive yet: `glxinfo` renderer goes from `llvmpipe` to `virgl (Adreno (TM) 830)`, offscreen `peglgears` 4.2k → 39.3k FPS.
  - **Opt-in per profile, and honest about the trade:** the socket is a channel from the box to a host GPU server and vtest is not a hardened protocol, so this is a deliberate (small) widening of the box boundary. Off unless you set it. Only the socket is bound — never the whole `$TMPDIR` (`--shared-tmp`), which would shadow the box's own `/tmp` (hiding the Xvnc socket) and hand the box read/write over the host tmp dir.
  - **Never costs you the desktop:** missing Termux package, server that won't start, no socket, failed in-box Mesa install — each degrades to CPU rendering with a warning and the desktop still opens. The launch summary states which one you got.
  - Everything needed is installed on demand: `x11-repo` + `virglrenderer-android` on the host, and `libgl1-mesa-dri` + `mesa-utils` in the box (stock Debian/Ubuntu already carry mesa's virgl client — no custom Mesa build). The in-box part happens at **launch**, not build, so desktop boxes created before this release pick it up without a rebuild.
  - chromium's flags are now rewritten at every launch instead of only at build time, so toggling `GPU=` takes effect after `ab stop` + relaunch: `--disable-gpu` when off, `--ignore-gpu-blocklist` when on (chromium blocklists the virgl renderer otherwise). Verify inside the desktop with `glxinfo -B`, or `chrome://gpu`.
- **Reworked the Termux extra-keys row** for what agentbox is actually used for — a TUI agent inside tmux, one thumb. `HOME`/`END`/`PGUP`/`PGDN` move onto **long-press** of the arrow they already sat above (nothing became unreachable), and the four freed slots become one-tap macros that used to be chords through the sticky `CTRL` toggle: **⏎↵** (`\` + Enter — a newline that does *not* submit, for multi-line prompts), **^C**, **det** (`Ctrl-b d`, detach the session), **scr** (`Ctrl-b [`, tmux copy-mode, since this config runs `mouse off`). `⇧⇥` (Claude Code mode cycle), `/`+`~`, `-`+`|` and the arrow inverted-T are unchanged; `CTRL`/`ALT`/`ESC` still appear exactly once each, as Termux requires. Applied by `ab setup`; your own lines above the managed marker are preserved, and `AGENTBOX_EXTRA_KEYS=…` still overrides the whole row (`=none` to skip it).
- **Templates:** `desktop` (v3.18.0) turns `GPU=virgl` on — its old GPU note promised Turnip/Zink acceleration that cannot work under proot on Android, and its `gpu <cmd>` wrapper now routes through virgl instead of Zink; the dead `mesa-vulkan-drivers`/`vulkan-tools` install is dropped. `web` (v3.18.0) ships the option commented out.

## 3.17.0
- **Verb-first box commands + `ab run`.** The box name used to float — 1st word to run (`ab claude`), 2nd word to manage (`ab save claude`). Now every box action reads as `ab <verb> <name>`: added a canonical **`ab run <name> [cmd]`** (what `ab <name>` already did), kept **`ab <name>`** as its shorthand, and added **`ab rm`** as an alias for `remove`. A box whose name collides with a reserved command — e.g. one literally named `save` — is no longer a dead end: it runs via `ab run save` (the `ab <name>` shorthand is shadowed, and box creation now says so).
- **`ab upgrade <name>`** — refresh a built box's packages **in place**: `apt-get update && upgrade` plus a re-run of its (idempotent) agent/PKGS recipe, so the CLI agent (Claude Code, etc.) and apt packages move to latest **without deleting the rootfs — no re-download**. Fills the gap between `ab update` (updates agentbox itself, never box contents) and `ab rebuild` (wipes + reinstalls from scratch). Docker-mode boxes (`INSTALL` set) re-run those steps verbatim; the desktop stack still needs a rebuild.

## 3.16.0
- **Host-shell terminal self-heal after an ssh drop.** When a box's TUI agent (Claude Code, etc.) has mouse tracking / bracketed paste on and the ssh connection *drops* (rather than detaching cleanly), tmux never gets to restore the outer terminal — so on reconnect you land at the Termux host shell and every mouse move spills escape codes (`\e[<…M`) straight into the command line. agentbox now installs a managed `PROMPT_COMMAND` block in `~/.bashrc` that disables those modes (mouse 1000/1002/1003/1006, bracketed paste 2004, focus 1004, cursor) before each **host** prompt — outside tmux only, and a silent no-op when nothing leaked. Because ssh opens a *login* shell (which sources `.bash_profile` and skips `.bashrc`), a `~/.bash_profile` bridge is added too so the heal actually loads over ssh. Installed by `ab setup` (the "set up Termux" step) and on every `ab <name>` session open; idempotent, backs `~/.bashrc` up once to `.bashrc.bak`. Reattaching a session (`ab session`) already worked — this covers the "reconnect straight to the host shell" path.

## 3.15.0
- **`ab pw <name> [password]`** — set (or show) a desktop box's login password instead of the random one generated each launch. Stored 0600 at `~/.config/agentbox/gui-<name>.pw`; applies on the next launch.
- **`LAN=1`** profile option (desktop boxes) — also serve the KasmVNC desktop on your Wi-Fi (`http://<phone-ip>:6902`), not just localhost. Default `0` (localhost only). mitmweb stays local. The desktop is password-protected; set a strong one with `ab pw` before exposing it.
- The desktop's on-screen hints now split "close" and "rebuild" onto two lines.

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
