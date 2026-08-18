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
- **C++ builds must run in the x64 developer environment.** A plain shell (Git Bash
  or PowerShell) has `LIB` pointing at **x86**, so compilation succeeds but the link
  dies with hundreds of unresolved externals plus `LNK4272: library machine type
  'x86' conflicts with target machine type 'x64'`. Build from Visual Studio, or wrap
  the command:
  `cmd /c '"C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul && python tools\build.py --target xi_map --build-only'`
  (vcvars64 prints a harmless `'vswhere.exe' is not recognized` and works anyway.)
- **After a Visual Studio / MSVC update, clear the stale PCHs.** They are locked to
  the compiler that built them, so the next build fails with `fatal error C1853:
  precompiled header file is from a different version of the compiler`. Delete
  `cmake_pch.cxx.pch` / `.obj` under `build/src/**/CMakeFiles/*.dir/` (leave the
  separate `build/x64-Debug` and `build/x64-Release` VS dirs alone) and rebuild.
  Seen 2026-08-15: `build/` was configured 2026-06-26, MSVC updated 2026-08-04.
- **Verify build success from the log, not the exit code** — piping the build through
  `tail`, or appending an `echo`, makes the shell report the *last* command's status
  and a failed build looks like exit 0. Check for `LNK`/`FAILED`/`fatal error` in the
  output and confirm the `xi_map.exe` timestamp actually moved.
- Stop the server before building: the link cannot overwrite a running `xi_map.exe`.
- Start/stop: `C:\ffxi\start-server.bat`, `C:\ffxi\stop-server.bat`.
- Characters: **Kane** (main), Amalie (Taru), Buzzykins (retired GM-test).

## Git workflow

- Fork: `msintome/server` (remote `origin`); upstream LSB is remote `upstream`.
- **`xilife` is the main line of development for this project.** All feature work
  merges *into* `xilife`. `ms-base` is the staging point where upstream LSB lands,
  and `xilife` merges `ms-base` to pick that up. The flow is
  `upstream base → ms-base → xilife`, and `feature branch → xilife`.
- **Cut feature branches from `xilife`, and merge them back into `xilife`** — not
  into `ms-base`. (Corrected 2026-08-16: this file previously said custom work
  belonged on `ms-base`, and the city PlayerNPC work was merged there first as a
  result. `ms-base` consequently still carries that custom work; it was left
  alone rather than rewriting pushed history, and costs nothing in practice since
  almost all of it lives in `modules/custom/` and `tools/`, which upstream never
  touches.)
- **Before really big or experimental changes, copy the branch first**
  (`git branch xilife-<what> xilife`) so there is a known-good state to return
  to. This is the safety net that replaces strict branch separation.
- **Merge-based, not rebase.** Commit working checkpoints incrementally. Tag
  known-good states.
- Push to `origin` only, by explicit branch name. Never push to `upstream`.
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

### XI_LIFE (branches `xilife`, `claude-skipping-fix`) — PlayerNPC city population

Adds player-looking NPCs to cities for a retail feel. Working in **Upper Jeuno**:
five random PlayerNPCs (random race/face/gear), gear persistence, pathfinding,
standing at POIs and walking between them. Nameplate persistence partially resolved
(correct on re-entry via fresh spawn packet; brief disappearance on initial spawn is
an accepted limitation).

**Active branch: `claude-skipping-fix`** (cut from `xilife`, has `ms-base` merged in
so the docs travel with it). Holds the movement fix below; not yet merged back to
`xilife`. Continue here. Note the two `spawnOnePNPC` calls in `Upper_Jeuno/Zone.lua`
are now live — comment them out again to disable the population system. Zone scripts
only reload on **map server restart**, unlike NPC/mob scripts.

- **OPEN 2026-08-18 — PlayerNPCs standing above Lower Jeuno's auction house**
  (branch `claude-npc-spacing`). Three attempted fixes have **not** resolved it;
  the mechanism below is a hypothesis that has so far failed to predict the
  behaviour, so treat it as unconfirmed rather than as the answer.
  Hypothesis: slots are validated with `zone:isNavigablePoint`, which picks with a
  1 yalm vertical extent (`smallPolyPickExt`, `navmesh/navmesh.cpp`), while
  `pathTo` routes via `findPath` using 5 yalms (`polyPickExt`). Lower Jeuno's
  auction counters sit at `y -0.101` with structure roughly five yalms above them
  (**negative y is up**), inside that window, so a route endpoint could snap to the
  walkway. Tried and insufficient: `zone:getFloorId` equality (reads the *XiMesh*,
  not the navmesh — the walkway shares a map block with the floor below); probing
  each slot at two heights overhead and dropping vertically ambiguous ones; a
  height check on arrival that retires the slot. A stuck watchdog also runs on the
  encounter tick.
  **Next step is instrumentation, not another fix.** Log the actual slot
  coordinates built for zone 245, and the PlayerNPC's real `y` on arrival versus
  the point's `y`, and confirm from the startup line whether the rings are being
  pruned at all. If arrivals are landing at the *correct* `y`, the whole vertical
  theory is wrong and the cause is elsewhere. Falling back to the pre-ring
  behaviour for auction points (jittered arrival at the counter, no ring) is a
  known-good escape hatch.

- **RESOLVED 2026-08-15 — "skipping" movement** (branch `claude-skipping-fix`,
  verified in client: they now walk and run with a continuous animation cycle).
  The speed/`speedsub` hypothesis was **wrong** — `GetSpeed()` and `animationSpeed`
  are written correctly to `0x1C`/`0x1D` and were never the problem.
  Real cause was a **packet offset collision at `0x18`**: the `UPDATE_POS` block in
  `entity_update.cpp` writes `loc.p.moving` there, but the every-update rename path
  for equipped-look dynamic NPCs then wrote `0x01` to the same offset (the flag that
  makes the client read the long name from `0x44`), clobbering the low byte.
  `CPathFind` advances `loc.p.moving` by `0x35` per tick (wraps at `0x2000`), and
  `common/mmo.h` calls it "the number of steps required for correct rendering in the
  client" — so the client saw the counter stall ~5 ticks then jump `0x100`, and kept
  restarting the "start running" animation instead of settling into the run cycle.
  Fix: exclude these entities from the per-update rename block. They get their name
  from the `ENTITY_SPAWN` path and have no client-side default name to revert to, so
  the rename was never needed for them.
- **Watch for more offset collisions.** This was the *second* one in this packet: the
  earlier bug wrote the name at `0x34` over the gear model IDs at `0x34-0x43`. When
  dynamic-NPC work misbehaves visually, suspect two writers to one offset before
  suspecting game logic. Note `isRenamed` is set unconditionally for **every**
  `insertDynamicEntity` (`luautils.cpp`), so all such NPCs hit the rename path.
- **Fallback if nameplates regress:** gate the name layout on `loc.p.moving == 0`
  instead of excluding it, so names refresh while standing at a POI but never
  interfere while walking. Not needed as of the 2026-08-15 test.
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
