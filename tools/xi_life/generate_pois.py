# -*- coding: utf-8 -*-
"""
XI_LIFE point-of-interest generator.

Builds the table of places PlayerNPCs walk to, for every city zone, from the database and the
zone scripts. Emits two files from one pass:

  tools/xi_life/pois.json             - the human-facing artifact. Diff it, hand-edit it, veto
                                        bad points in it.
  modules/custom/lua/xi_life_pois.lua - what the map server actually loads. Generated; do not
                                        edit by hand.

Three kinds of point are collected, all of them places a real player actually goes:

  exit      - zone lines out of the zone, from the `zonelines` table.
  homepoint - home point crystals, from `npc_list`. Unplaced placeholder rows sitting at the
              origin are dropped; Upper Jeuno alone ships two of them.
  auction   - auction house counters. These need two sources and neither is complete on its own:
              some zones have NPCs literally named Auction_Counter in `npc_list`, others have
              individually named NPCs whose script calls sendMenu(xi.menuType.AUCTION). Upper
              Jeuno has zero of the former and four of the latter.

Note that positions are only *candidates*. Whether a point is standing on the navmesh cannot be
answered here - the mesh lives in the running map process - so the runtime validates each point
with zone:isNavigablePoint on startup and drops what it cannot reach.

Usage (from the repo root):

    python -m tools.xi_life.generate_pois
    python -m tools.xi_life.generate_pois --dry-run
"""

import argparse
import json
import math
import os
import re
import sys
from collections import defaultdict

try:
    import mariadb
except ImportError:
    sys.exit("mariadb module not found. Run: pip install -r tools/requirements.txt")


# npc_list keys every NPC by a global id; the zone it belongs to is encoded in it.
NPCID_BASE = 16777216
NPCID_ZONE_STRIDE = 4096

# xi.zoneType.CITY, from scripts/enum/zone_type.lua. It is a bitmask, so test the bit.
ZONETYPE_CITY = 0x0001

# A "city" zone with almost no NPCs, or with no way out, is not somewhere a PlayerNPC can live a
# plausible life. This drops Chocobo Circuit, the Colosseum, Mog Garden, Heaven's Tower, the
# Residential Area stubs and friends without naming any of them.
MIN_NPCS_FOR_POPULATION = 50

# Population scales with the square root of the zone's NPC count rather than linearly. Linear
# scaling pins every large city to the cap and loses all discrimination between them; sqrt keeps
# Southern San d'Oria (542 NPCs) at 19 while holding Upper Jeuno (148 NPCs) at 10, which is the
# density that was tuned by eye in game.
POPULATION_COEFFICIENT = 0.822
POPULATION_MIN = 2
POPULATION_MAX = 22

# Two auction counters a few yalms apart are one destination as far as a walking NPC is concerned.
DEDUPE_PRECISION = 1.0

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
JSON_OUTPUT = os.path.join(REPO_ROOT, "tools", "xi_life", "pois.json")
LUA_OUTPUT = os.path.join(REPO_ROOT, "modules", "custom", "lua", "xi_life_pois.lua")

AUCTION_MENU_PATTERN = re.compile(r"menuType\.AUCTION")


def fetch_credentials():
    """Read settings/network.lua, with the same environment overrides dbtool honours."""

    settings = {}
    network_path = os.path.join(REPO_ROOT, "settings", "network.lua")

    if os.path.exists(network_path):
        with open(network_path, encoding="utf-8") as handle:
            for line in handle:
                if "=" not in line or line.strip().startswith("--"):
                    continue

                key, value = line.split("=", 1)
                settings[key.strip()] = value.strip().rstrip(",").strip("'\" ")

    def setting(name, fallback):
        return os.getenv("XI_NETWORK_" + name) or settings.get(name, fallback)

    return {
        "host": setting("SQL_HOST", "127.0.0.1"),
        "port": int(setting("SQL_PORT", 3306)),
        "user": setting("SQL_LOGIN", "root"),
        "password": setting("SQL_PASSWORD", ""),
        "database": setting("SQL_DATABASE", "xidb"),
    }


def text(value):
    """The connector hands back tinytext columns as bytes, so normalise everything to str."""

    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8", "replace")

    return value


def population_for(npc_count):
    scaled = round(POPULATION_COEFFICIENT * math.sqrt(npc_count))
    return int(max(POPULATION_MIN, min(POPULATION_MAX, scaled)))


def point_key(point):
    return (
        point["kind"],
        round(point["x"] / DEDUPE_PRECISION),
        round(point["z"] / DEDUPE_PRECISION),
    )


def scan_scripted_auction_npcs():
    """
    Find NPCs whose script opens the auction menu.

    The zone directory name matches zone_settings.name and the script filename matches the
    npc_list name, so the pair is enough to look the position up later.
    """

    found = defaultdict(set)
    zones_root = os.path.join(REPO_ROOT, "scripts", "zones")

    if not os.path.isdir(zones_root):
        return found

    for zone_name in os.listdir(zones_root):
        npc_dir = os.path.join(zones_root, zone_name, "npcs")
        if not os.path.isdir(npc_dir):
            continue

        for filename in os.listdir(npc_dir):
            if not filename.endswith(".lua"):
                continue

            path = os.path.join(npc_dir, filename)
            try:
                with open(path, encoding="utf-8") as handle:
                    if AUCTION_MENU_PATTERN.search(handle.read()):
                        found[zone_name].add(filename[:-4])
            except OSError as error:
                print("  ! could not read {}: {}".format(path, error))

    return found


def collect(cursor):
    """Pull every zone's candidate points out of the database and the zone scripts."""

    cursor.execute(
        "SELECT zoneid, name FROM zone_settings WHERE zonetype & %s ORDER BY zoneid",
        (ZONETYPE_CITY,),
    )
    city_zones = {row[0]: text(row[1]) for row in cursor.fetchall()}

    # Every placed NPC, so we can both count them and pick out the ones we care about by name.
    cursor.execute(
        "SELECT FLOOR((npcid - %s) / %s), name, pos_x, pos_y, pos_z"
        "  FROM npc_list"
        " WHERE NOT (pos_x = 0 AND pos_y = 0 AND pos_z = 0)",
        (NPCID_BASE, NPCID_ZONE_STRIDE),
    )

    npc_counts = defaultdict(int)
    npc_positions = defaultdict(dict)
    points = defaultdict(list)

    for zone_id, name, pos_x, pos_y, pos_z in cursor.fetchall():
        zone_id = int(zone_id)
        name = text(name)
        if zone_id not in city_zones:
            continue

        npc_counts[zone_id] += 1
        npc_positions[zone_id][name] = (pos_x, pos_y, pos_z)

        if name.startswith("HomePoint"):
            points[zone_id].append(
                {"name": name, "kind": "homepoint", "x": pos_x, "y": pos_y, "z": pos_z}
            )
        elif name == "Auction_Counter":
            points[zone_id].append(
                {"name": name, "kind": "auction", "x": pos_x, "y": pos_y, "z": pos_z}
            )

    # Auction NPCs that are not named Auction_Counter, resolved by script scan.
    scripted = scan_scripted_auction_npcs()
    zone_ids_by_name = {name: zone_id for zone_id, name in city_zones.items()}

    for zone_name, npc_names in scripted.items():
        zone_id = zone_ids_by_name.get(zone_name)
        if zone_id is None:
            continue

        for npc_name in sorted(npc_names):
            position = npc_positions[zone_id].get(npc_name)
            if position is None:
                print(
                    "  ! {}: {} opens the auction menu but has no placed row in npc_list".format(
                        zone_name, npc_name
                    )
                )
                continue

            points[zone_id].append(
                {
                    "name": npc_name,
                    "kind": "auction",
                    "x": position[0],
                    "y": position[1],
                    "z": position[2],
                }
            )

    cursor.execute(
        "SELECT z.from_zone, z.to_zone, s.name, z.from_pos_x, z.from_pos_y, z.from_pos_z"
        "  FROM zonelines z"
        "  LEFT JOIN zone_settings s ON s.zoneid = z.to_zone"
        " ORDER BY z.from_zone, z.to_zone"
    )

    for from_zone, to_zone, to_name, pos_x, pos_y, pos_z in cursor.fetchall():
        to_name = text(to_name)
        if from_zone not in city_zones:
            continue

        # A zone line back into the same zone is a Mog House door, not a way out of town.
        if from_zone == to_zone:
            label = "Mog House door"
        else:
            label = "{} exit".format(to_name or "Zone {}".format(to_zone))

        points[from_zone].append(
            {"name": label, "kind": "exit", "x": pos_x, "y": pos_y, "z": pos_z}
        )

    return city_zones, npc_counts, points


def build_zones(city_zones, npc_counts, points):
    zones = []
    skipped = []

    for zone_id, zone_name in sorted(city_zones.items()):
        npc_count = npc_counts.get(zone_id, 0)

        deduped = {}
        for point in points.get(zone_id, []):
            deduped.setdefault(point_key(point), point)

        zone_points = sorted(deduped.values(), key=lambda p: (p["kind"], p["name"]))
        exits = [p for p in zone_points if p["kind"] == "exit"]

        if npc_count < MIN_NPCS_FOR_POPULATION:
            skipped.append((zone_name, "only {} placed NPCs".format(npc_count)))
            continue

        if not exits:
            skipped.append((zone_name, "no zone lines out"))
            continue

        zones.append(
            {
                "zoneId": zone_id,
                "zoneName": zone_name,
                "npcCount": npc_count,
                "population": population_for(npc_count),
                "points": zone_points,
            }
        )

    return zones, skipped


def write_json(zones, path):
    payload = {
        "_comment": "Generated by tools/xi_life/generate_pois.py. Safe to hand-edit; "
        "re-running the generator overwrites it.",
        "populationModel": {
            "coefficient": POPULATION_COEFFICIENT,
            "min": POPULATION_MIN,
            "max": POPULATION_MAX,
            "note": "population = clamp(round(coefficient * sqrt(npcCount)), min, max)",
        },
        "zones": zones,
    }

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, indent=4)
        handle.write("\n")


def write_lua(zones, path):
    lines = [
        "-----------------------------------",
        "-- XI_LIFE PlayerNPC points of interest",
        "--",
        "-- GENERATED FILE - do not edit by hand.",
        "-- Regenerate with: python -m tools.xi_life.generate_pois",
        "--",
        "-- Positions are candidates only. The navmesh cannot be consulted from the generator, so",
        "-- the runtime validates each point with zone:isNavigablePoint before using it.",
        "-----------------------------------",
        "xi = xi or {}",
        "xi.xiLife = xi.xiLife or {}",
        "",
        "xi.xiLife.pois =",
        "{",
    ]

    for zone in zones:
        lines.append("    [{}] = -- {}".format(zone["zoneId"], zone["zoneName"]))
        lines.append("    {")
        lines.append("        population = {},".format(zone["population"]))
        lines.append("        points =")
        lines.append("        {")

        for point in zone["points"]:
            lines.append(
                "            {{ name = '{}', kind = '{}', x = {:.3f}, y = {:.3f}, z = {:.3f} }},".format(
                    point["name"].replace("\\", "\\\\").replace("'", "\\'"),
                    point["kind"],
                    point["x"],
                    point["y"],
                    point["z"],
                )
            )

        lines.append("        },")
        lines.append("    },")
        lines.append("")

    lines.append("}")
    lines.append("")
    # Returned as well as assigned, so the file is valid whether it is require()d by the module or
    # picked up directly by the module loader, which rejects any file that does not return a table.
    lines.append("return xi.xiLife.pois")
    lines.append("")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description="Generate XI_LIFE PlayerNPC points of interest.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="report what would be generated without writing any files",
    )
    args = parser.parse_args()

    credentials = fetch_credentials()
    print(
        "Connecting to {}@{}:{}/{}".format(
            credentials["user"],
            credentials["host"],
            credentials["port"],
            credentials["database"],
        )
    )

    try:
        connection = mariadb.connect(**credentials)
    except mariadb.Error as error:
        sys.exit("Could not connect to the database: {}".format(error))

    with connection:
        cursor = connection.cursor()
        city_zones, npc_counts, points = collect(cursor)

    zones, skipped = build_zones(city_zones, npc_counts, points)

    print("")
    print(
        "{:<28} {:>5} {:>5} {:>6} {:>5} {:>8}".format(
            "zone", "npcs", "pop", "exits", "hp", "auction"
        )
    )
    print("-" * 62)

    totals = defaultdict(int)
    for zone in zones:
        counts = defaultdict(int)
        for point in zone["points"]:
            counts[point["kind"]] += 1
            totals[point["kind"]] += 1

        print(
            "{:<28} {:>5} {:>5} {:>6} {:>5} {:>8}".format(
                zone["zoneName"][:28],
                zone["npcCount"],
                zone["population"],
                counts["exit"],
                counts["homepoint"],
                counts["auction"],
            )
        )

    print("-" * 62)
    print(
        "{} zones, {} exits, {} home points, {} auction counters".format(
            len(zones), totals["exit"], totals["homepoint"], totals["auction"]
        )
    )

    loiterless = [z["zoneName"] for z in zones if not any(p["kind"] != "exit" for p in z["points"])]
    if loiterless:
        print("")
        print("Transit only (no home point or auction counter to loiter at):")
        for zone_name in loiterless:
            print("  - {}".format(zone_name))

    if skipped:
        print("")
        print("Skipped {} city zones:".format(len(skipped)))
        for zone_name, reason in skipped:
            print("  - {} ({})".format(zone_name, reason))

    if args.dry_run:
        print("")
        print("Dry run, nothing written.")
        return

    write_json(zones, JSON_OUTPUT)
    write_lua(zones, LUA_OUTPUT)

    print("")
    print("Wrote {}".format(os.path.relpath(JSON_OUTPUT, REPO_ROOT)))
    print("Wrote {}".format(os.path.relpath(LUA_OUTPUT, REPO_ROOT)))


if __name__ == "__main__":
    main()
