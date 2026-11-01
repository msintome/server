# AmalieXI companion

A second-screen web app: a live top-down map of the zone you are in, plus your vitals, target,
effects, EXP (with EXP/hour), crafts and gil.

## Running it

```
cd tools\companion
npm install
npm start
```

Then open http://127.0.0.1:8095/. It listens on localhost only.

It needs the `companion_exporter` module loaded on the map server (`custom/lua/companion_exporter.lua`
in `modules/init.txt`), which writes `log/companion_<Name>.json` once a second.

## Where the data comes from

| Panel | Source |
|---|---|
| Map, position, facing, zone, weather | `log/companion_<Name>.json` from the exporter, streamed to the page |
| HP / MP / TP, job, target, effects | the same snapshot |
| EXP, crafts, gil | `xidb` (`char_exp`, `exp_base`, `char_skills`, `char_inventory`), polled every 5 s |
| Map geometry | `navmeshes/<Zone_Name>.nav`, the server's own pathfinding mesh |

The map is the navmesh: the walkable floor the server pathfinds on, shaded by height. It is in the
server's own coordinates, so the position marker needs no calibration. North is up.

## Database login

Without a `config.json`, the app uses the `SQL_*` settings from `settings/network.lua`, the same login
the servers use. It only ever runs SELECTs, but a read-only user is better. Copy
`config.example.json` to `config.json` (gitignored) and fill in a user with SELECT on `xidb`. It
must use `mysql_native_password`, because mysql2 cannot do GSSAPI.

`COMPANION_PORT` overrides the port.

## API

- `GET /api/live`: the latest snapshot for each character
- `GET /api/live/stream`: server-sent events, one `data:` line per new snapshot
- `GET /api/navmesh/<Zone_Name>`: `{ bounds, verts: [x, y, z, ...], polys: [[flags, i0, i1, ...], ...] }`
- `GET /api/progress/<charId>`: EXP, TNL, merits, limits, gil and crafts for the character's current job
- `GET /api/health`: database status and which characters are exporting
