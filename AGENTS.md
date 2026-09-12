# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

@amaliexi-context.md

## Project

LandSandBoat (LSB) is an open-source FFXI server emulator. C++20 core (`src/`) plus a very large LuaJIT
game-content layer (`scripts/`, `modules/`), backed by MariaDB (`sql/`).

**Read `documentation/ai_agents/README.md` before doing content work.** The project has explicit
expectations for AI-assisted contributions: FFXI-specific and LSB-specific logic must be verified against
retail captures, event dumps, wikis, and the game client. Unverified guesses are worse than nothing here.
Companion guides in the same directory:
- `retail-packet-captures.md` — how to read `eventview` / `npclogger` / `caplog` / `packetviewer` data
- `interaction-framework-migration.md` — converting old-style NPC scripts to the Interaction Framework
- `npc-header-guide.md` — required NPC script header format, finding zone IDs and positions

## Commands

Build (CMake presets; binaries are staged to the repo root, and all servers run from the repo root):

```bash
python ./tools/build.py                    # configure + build everything (RelWithDebInfo)
python ./tools/build.py --target xi_map    # single target: xi_map, xi_world, xi_connect, xi_search, xi_test
python ./tools/build.py --preset debug     # Debug build
python ./tools/build.py --build-only       # skip configure
```

Equivalent raw CMake: `cmake --preset default` then `cmake --build --preset default` (with presets the
build dir comes from the preset, so no `build` path argument).

Database (credentials come from `settings/network.lua`):

```bash
python ./tools/dbtool.py            # interactive menu
python ./tools/dbtool.py update     # express update + migrations (what CI runs)
python ./tools/dbtool.py update full
python ./tools/dbtool.py migrate
python ./tools/dbtool.py backup [lite]
```

`update` imports upstream SQL over the live `xidb`, which holds real character data on this server, and
the checkout is deliberately version-pinned — so treat `update`/`migrate` as an explicit-request-only
operation, and back up first. dbtool shells out to the MariaDB client, which is not on PATH here; it
stores the resolved path in its own config, so if it cannot find `mysql` point it at the MariaDB 10.11
`bin` directory rather than assuming a bare `mysql` works.

Tests — `xi_test` boots embedded world+map engines in one process and runs the Lua suites in
`scripts/tests/`. Run from the repo root, against a live database:

```bash
./xi_test                                        # everything
./xi_test --keep-going --output tests.ctrf.json  # CI invocation
./xi_test --file systems/spells                  # only test files matching regex
./xi_test --filter 'Accession'                   # only test names matching regex
./xi_test --tag blu                              # only #tagged describes (tags are '#tag' in the describe name)
./xi_test --no-tag benchmark --verbose
```

Lint / CI checks (`tools/ci/sanity_checks.sh` runs all of these; needs luacheck, cppcheck, clang-format):

```bash
./tools/ci/sanity_checks.sh                       # everything
./tools/ci/sanity_checks.sh origin/base           # only files changed since a ref, plus commit-message checks
python tools/ci/sanity_checks/lua_stylecheck.py <file.lua>
bash tools/ci/sanity_checks/lua.sh <file.lua>     # luacheck with LSB's global whitelist
bash tools/ci/sanity_checks/cpp.sh <file.cpp>     # cppcheck + clang-format -i (formats in place!)
python ./tools/run_clang_format.py                # format all C++, from repo root
python ./tools/ci/lua_lang_server.py              # Lua Language Server type check
python -m tools.ci.startup_checks [multi]         # boot the servers and assert a clean startup
```

Python deps: `pip install -r tools/requirements.txt` (mariadb, GitPython, PyYAML, colorama, pyzmq,
jinja2, jsonschema — the last three are required by CMake configure).

The `.sh` checks above are bash, not PowerShell — run them through the Bash tool (Git Bash), and expect
the `luacheck` / `cppcheck` dependencies to be missing unless installed. `lua_stylecheck.py`,
`run_clang_format.py`, and the codegen/dbtool entry points are plain Python and run fine from PowerShell.

## Architecture

### Processes

Five executables, all run from the repo root so they can find `scripts/`, `settings/`, `data/`, and the
runtime DLLs:

- **`xi_connect`** (`src/login/`) — login/auth. Session types split across `auth_session`, `data_session`,
  `view_session`.
- **`xi_world`** (`src/world/`) — one per cluster. Owns cross-zone state that must not be duplicated:
  parties/alliances, conquest, campaign, besieged, colonization, character cache, Vana'diel time.
- **`xi_map`** (`src/map/`) — the game server. One or more processes, each owning a subset of zones
  (`dbtool` menu options configure single-process or modulus-3/7 multi-process splits).
- **`xi_search`** (`src/search/`) — auction house / player search.
- **`xi_test`** (`src/test/`) — test harness that embeds a `WorldEngine` and `MapEngine` in-process.

Everything shares `src/common/` (`Application`/`Engine` lifecycle, `Scheduler`, settings, logging,
database, ZMQ, Lua state).

### Concurrency

Asio-based coroutines (`Task<T>`) driven by `Scheduler` in `src/common/scheduler.h`. Game logic runs on
the main thread; use `postToMainThread` / `spawnOnMainThread` / `spawnOnWorkerThread`. `blockOnMainThread`
exists for startup and tests, not for regular code.

### IPC

`xi_map` ↔ `xi_world` messaging over ZMQ. Message structs are declared in `src/common/ipc_structs.h` and
listed by name in `tools/generate_ipc_stubs.py`, which CMake runs at configure time to emit
`build/generated/ipc_stubs.h`. **Adding an IPC message means editing both the struct header and the name
list in the generator.** In `xi_test` the transport is switched to `inproc://`.

### Code generation

`python -m tools.codegen <build_dir>` reads `data/*.yaml`, `data/enums/*.yaml`, and
`data/schemas/*.schema.json`, emits C++ into `build/generated/data/`, and writes Lua enums into
`scripts/enum/` as **`*.codegen.lua`**. CMake bootstraps this on first configure and re-runs it via the
`data_codegen` target.

**Only the `.codegen.lua` files are generated, and this checkout is pre-YAML-enum-migration** — 7
generated files (gitignored) versus 123 hand-written `.lua` files that are themselves the source of
truth. Notably there is no `data/enums/mod.yaml`; modifiers live in `scripts/enum/mod.lua` and
`src/map/modifier.h`, and that is where you edit them. Before assuming an enum is YAML-driven, check
whether a matching `data/enums/<name>.yaml` actually exists.

### Map server internals (`src/map/`)

- `entities/` — `CBaseEntity` → `CBattleEntity` → `CCharEntity` / `CMobEntity` / `CPetEntity` /
  `CTrustEntity` / `CAutomatonEntity` / `CFellowEntity`; `npc_entity` for non-combatants.
- `ai/` — `CAIContainer` per entity, driving a `controller` (player, mob, pet, trust, automaton) through
  `states/` (attack, magic, ability, mobskill, range, item, death, despawn). Helpers: `pathfind`,
  `targetfind`, `action_queue`, `gambits_container`.
- `zone.cpp` / `zone_entities.cpp` / `zone_instance.cpp` — per-zone tick, entity registry, and instanced
  content; `spatial_grid.cpp` narrows aggro/proximity work.
- `packets/` + `packet_system.cpp` — client packet parsing and the outgoing packet types.
- `lua/` — sol2 bindings. `lua_base_entity.cpp` is the huge `CBaseEntity` binding surface;
  `luautils.cpp/.h` holds the C++→Lua hook dispatch (`OnZoneIn`, `OnTrigger`, `OnMobDeath`, …) and the
  script cache.

### Lua content layer

- `scripts/zones/<Zone_Name>/` — `Zone.lua`, `IDs.lua`, `DefaultActions.lua`, plus `npcs/` and `mobs/`
  files named after the entity.
- `scripts/globals/` — shared game systems. `scripts/globals/interaction/` is the Interaction Framework
  (quests/missions as "containers" of sections; see `documentation/interaction-framework.md`) used by
  `scripts/quests/` and `scripts/missions/`.
- `scripts/actions/` — abilities, spells, weaponskills, mobskills. `scripts/effects/` — status effects.
  `scripts/mixins/` — reusable mob behaviours applied by family/zone. `scripts/commands/` — GM commands.
- `scripts/enum/` — generated enums, cached at startup; never `require` them.
- `scripts/tests/` — the `xi_test` suites (`describe`/`it`, with `xi.test.world:spawnPlayer` and the
  `player.assert:` chain).

### Settings

`settings/default/*.lua` are the tracked defaults; `settings/*.lua` are local overrides and are
**gitignored**. Everything lands on the global `xi.settings` table, readable from C++ and Lua. Server
processes also read `XI_NETWORK_SQL_*` environment variables (that's how CI configures the database).

### Modules

`modules/` holds opt-in overlays; `modules/init.txt` lists which files/folders load (`.lua` at runtime,
`.cpp` compiled in by CMake, `.sql` via dbtool). Lua modules use `Module:new(...)` +
`m:addOverride('path.to.function', ...)` with `super()` to call the original. `modules/era/lua/` mirrors
`scripts/` and guards overrides with `xi.module.isContentEnabled('<CONTENT_TAG>')` (COP, TOAU, WOTG,
ABYSSEA, SOA, ROV, TVR). `init.txt` is tracked but usually locally modified —
`git update-index --assume-unchanged modules/init.txt`.

## Conventions

C++: C++20, Allman braces, 4 spaces, trailing-return-type style (`auto f() -> T`) is common in newer code.
`.clang-format` is authoritative and CI fails on any diff it produces — run clang-format before pushing.
sol2 is compiled with all safeties on.

Lua (enforced by `tools/ci/sanity_checks/lua_stylecheck.py`, so worth knowing up front):
- 4 spaces, LF, single-quoted strings, final newline, no semicolons.
- Allman braces for multi-line tables; no single-line functions or conditions; blank line after `end`.
- Use enums, not magic numbers — many binding calls (`addItem`, `addKeyItem`, `hasItem`,
  `addStatusEffect`, `messageSpecial`, `npcUtil.giveItem`, …) reject numeric literals in specific
  parameters.
- Banned: `table.getn` (use `#t`), `os.time` (use `GetSystemTime`), `xi.items.` / `xi.effects.`, and
  `require`ing `scripts/enum`, `IDs`, or the legacy `scripts/globals/{items,keyitems,loot,msg,settings,
  spell_data,status,titles,zone}`.

Commits (checked by `tools/ci/sanity_checks/git.py`): title 10–72 characters, no `|`, no
"Update filename.lua"-style autogenerated messages, no filler words. Cite sources for retail behaviour in
comments or commit messages.

Note that the sections above describe **upstream LSB's** contribution standards. This checkout is a
private fork (see the branch model in the context file above), so the CI checks are a quality tool rather
than a gate — most valuable when touching `ms-base` or writing anything that might go upstream, and
optional for local `xilife` experiments. The Lua style rules are still worth following everywhere, since
they are what the rest of the codebase looks like.
