# AmalieXI — Project Context

> Companion to `CLAUDE.md`. Import from CLAUDE.md with `@amaliexi-context.md`.
> This file carries project decisions, gotchas, and conventions that reading the
> codebase won't reveal. It does **not** duplicate directory/build/dependency info
> that `/init` and the source already provide.

## What this is

AmalieXI: a private, **solo**, self-hosted Final Fantasy XI server on the
LandSandBoat (LSB) emulator, Windows 11. Single player. Goal: a rich, retail-like
solo experience across all expansions through the Rhapsodies of Vana'diel
conclusion, with custom tooling and populated-city atmosphere.

Marcus is a senior .NET / MariaDB / Visual Studio developer — build systems and DB
tooling are comfortable ground; the learning curve is FFXI/LSB internals and
Lua/C++ server scripting. **Not comfortable with command-line Git** — prefer Claude
Code to drive branch/commit/merge operations and explain each step.

## Version pin (important)

- Synced to upstream LSB `base` as of **2026-06-26** (merge #10403, `spatial_hashing`).
- **Deliberately frozen** on this LSB + retail-client pairing so quests/NPCs stay in
  sync. Do not pull upstream or bump versions without an explicit request.
- This checkout is **pre-YAML-enum-migration**. Enum/modifier layout lives in
  `scripts/enum/mod.lua` and `src/map/modifier.h` — **not** `data/enums/mod.yaml`
  (confirmed absent). Target the `.lua` / `.h` layout as primary.

## Environment / paths

- Server binaries: `C:\ffxi\` · LSB repo: `C:\ffxi\server`
- DB: MariaDB **10.11**, database `xidb`. Client: `C:\Program Files\MariaDB 10.11\bin\mariadb.exe`.
  MariaDB binaries are **not on PATH** — always use the full path (same for `mysqldump`).
- FFXI client: Steam (`D:\SteamLibrary\steamapps\common\FFXIPAL`), launched via
  Windower 4 with `--server 127.0.0.1`. Visuals: XIPivot + NextHD, dgVoodoo, ReShade.
- Tooling: HeidiSQL (queries), Visual Studio 2026 Community + CMake (C++ builds),
  Node.js (companion tooling), PowerShell (no `grep` — use
  `Get-ChildItem -Recurse -Include *.lua | Select-String`).
- Start/stop: `C:\ffxi\start-server.bat`, `C:\ffxi\stop-server.bat`.
- Characters: **Kane** (main), Amalie (Taru), Buzzykins (retired GM-test).

## Git workflow

- Fork: `msintome/server`. Branches: `ms-base` (tracks upstream `base`),
  `xilife` (custom work, built on top of `ms-base`).
- **Merge-based, not rebase.** Commit working checkpoints incrementally. Tag
  known-good states.
- When creating branches/commits, follow this model; keep changes small and
  verifiable, one step at a time.

## Conventions that differ from stock LSB

This is a customized fork. Table names, settings keys, and command names have
repeatedly turned out different from what stock LSB docs/general knowledge suggest,
so the actual source in `C:\ffxi\server` is ground truth here. Established facts:

- **Zone script callbacks:** use `afterZoneIn` (player fully loaded). `onZoneIn`
  fires mid-transition when `player:getZone()` is `nil`. `onPlayerEnter` does **not**
  exist in LSB. Zone scripts reload only on **map server restart**; NPC/mob scripts
  hot-reload via filewatcher.
- **World-server scheduling:** conquest tallies, daily tally, and the Gobbie Mystery
  Box depend on `xi_world.exe` running at specific JST-midnight windows. On a solo
  server that's only up during play sessions, those ticks never fire — the root cause
  of several "broken system" bugs. (Daily tally is worked around with Windows Task
  Scheduler + a retry batch: `C:\ffxi\daily_tally.bat`, logging to `daily_tally.log`,
  +50/day.)
- **Equip mechanism:** the map server holds character state in memory and overwrites
  the DB on persist — direct DB writes do **not** equip. Use in-game `/equip`
  (companion tooling copies `/equip` commands to clipboard; Windower paste).
- **MariaDB auth:** root uses GSSAPI, which the `mysql2` JS client can't negotiate.
  Dedicated app users need `mysql_native_password`
  (`ALTER USER ... IDENTIFIED VIA mysql_native_password USING PASSWORD(...)`).
- **Jobs bitmask:** `jobs & (1 << (jobId - 1))`. Level gate reads from `char_jobs`,
  not `char_stats`. Race restriction via mod 276.
- **Entity update packet:** name write at offset `0x34` overlaps look_t gear model IDs
  at the same offset — needs separate handling.
- **Client maintenance:** Steam "verify integrity" is safe with XIPivot (HD textures
  live in Windower's dirs, not the FFXI install). After a verify reset, re-patch via
  POL "Check Files" (available pre-login, no active subscription needed).

## Working style

- One step at a time; verify each stage before proceeding. No blind paste — explain
  the reasoning behind each change.
- Prefer **Lua** for iteration (no recompile/restart cycle); reserve **C++** for
  engine-level changes Lua can't reach.
- Functional over decorative; CLI-first before web UIs.
- LSB Lua reference generated from source: `amaliexi_lua_reference.html` (zone
  callbacks, `insertDynamicEntity` fields, look_t encoding, entity methods, enums).

---

## Project state & roadmap

> Reference-on-demand. If you want to shave always-loaded context later, split this
> section into its own file and `@`-reference it only when working on these areas.

### XI_LIFE (branch `xilife`) — PlayerNPC city population

Adds player-looking NPCs to cities for a retail feel. Working in **Upper Jeuno**:
five random PlayerNPCs (random race/face/gear), gear persistence, pathfinding,
standing at POIs and walking between them. Nameplate persistence partially resolved
(correct on re-entry via fresh spawn packet; brief disappearance on initial spawn is
an accepted limitation).

- **Open issue — "skipping" movement.** PlayerNPCs skip/teleport rather than walking
  smoothly — the main immersion-breaker. Leading hypothesis: movement speed/cadence in
  the entity update packet (`speed`/`speedsub` wrong or `0` → client snaps to each new
  position instead of interpolating and animating), since trusts (server-side entities)
  move smoothly. **Next step (deferred):** compare LSB trust/mob movement + speed fields
  against the `xilife` POI walker. Note #10403 `spatial_hashing` is in this build and
  sits near movement/visibility code — worth reading its diff when revisiting.
- **Alternative approach considered:** network-injection — a separate console app
  connecting as real PC session(s) so the retail client renders them via its
  player-interpolation path (smooth movement, plus real nameplates, `/sea`, and chat as
  a bonus). Higher fidelity, larger build (auth → world → map handshake, Blowfish +
  checksum, keepalive). Owning both ends allows a simplified localhost-handshake shortcut.

### FFXI companion web app (planned — second screen)

Single Node process, JSON API endpoints polling `xidb` live. Panels:

- **Levelling zone finder** — single-file HTML/JS, BG-Wiki camp data, draggable
  histogram, colour-coded detection badges, milestone gate cards, CP/AOE tabs,
  localStorage state. (Built.)
- **Missing spells** — `spell_list.jobs` binary blob decoded via
  `ORD(SUBSTR(jobs, jobId, 1))`.
- **Upcoming abilities/traits.**
- **Gear advisor** — `ffxi-gear` Node CLI → `xidb`, armour upgrade opportunities across
  head/body/hands/legs/feet, job weight profiles in `profiles.json`, WHM = DEF×1 MND×3.
  (Built.)
- **Interaction:** copy `/equip` commands to clipboard (direct DB writes ruled out — see
  equip mechanism above).

### Trust tuning

Shantotto II enmity fixed via `ENMITY -50` on spawn, `NOT_HAS_TOP_ENMITY` predicate on
offensive gambits, and a 3-second engage delay via `LOCALVAR_GTE` gambit condition
(custom C++ addition, enum value 36). Valaineral enmity mod raised to 50; full script
restored after it was found reduced to a skeleton. Best solo party: Valaineral (tank),
Sylvie UC (healer), Ulmia (BRD — Haste songs), Shantotto II (BLM damage).

### Maintenance watch

- `ms-base` / `xilife` upkeep as upstream evolves (Python codegen deps added upstream;
  YAML enum migration landed upstream ~July 2026 — **not** in this pinned checkout).
