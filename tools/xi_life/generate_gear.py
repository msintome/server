# -*- coding: utf-8 -*-
"""
XI_LIFE gear generator.

Emits modules/custom/lua/xi_life_gear.lua: the equipment models PlayerNPCs can be dressed in.

Two things come out of item_equipment:

  slots     - every distinct armour model at or below MAX_GEAR_LEVEL, per slot. Hundreds of
              options rather than the handful that were hand-picked, so a busy city stops looking
              like a uniformed militia.

  artifact  - the fifteen level 52-60 job Artifact sets, worn complete. These are what make a
              PNPC read as a real player rather than a randomly dressed mannequin.

Artifact sets fall out of the data cleanly: every piece of one shares a single model ID (WAR is 64
across all five slots, MNK 66, and so on up to SMN at 92). So the detection is simply "a job-locked
model in the right level band that covers all five armour slots", which also discards the handful
of non-Artifact items that share the band - restorer_cloak, cure_clogs, beacon_cuffs and friends.

look_t stores each slot as (slot_index << 12) | model, so the Lua side pairs these numbers with
the slot it is filling. See look_t in common/mmo.h.

Usage (from the repo root):

    python -m tools.xi_life.generate_gear
    python -m tools.xi_life.generate_gear --dry-run
"""

import argparse
import os
from collections import defaultdict

from tools.xi_life import db

# Classic-era gear. Higher than this drags in item-level equipment whose models look out of place
# next to the Artifact sets.
MAX_GEAR_LEVEL = 75

# Artifact armour is level 52-60 and locked to exactly one job.
ARTIFACT_MIN_LEVEL = 52
ARTIFACT_MAX_LEVEL = 60

# item_equipment.slot is a bitmask; these are the five armour slots a PNPC wears.
SLOT_BITS = {
    "head": 16,
    "body": 32,
    "hands": 64,
    "legs": 128,
    "feet": 256,
}

# item_equipment.jobs is a bitmask. Single bit set means the piece is locked to that job.
JOB_BITS = {
    1: "WAR",
    2: "MNK",
    4: "WHM",
    8: "BLM",
    16: "RDM",
    32: "THF",
    64: "PLD",
    128: "DRK",
    256: "BST",
    512: "BRD",
    1024: "RNG",
    2048: "SAM",
    4096: "NIN",
    8192: "DRG",
    16384: "SMN",
}

LUA_OUTPUT = os.path.join(
    db.REPO_ROOT, "modules", "custom", "lua", "xi_life_gear.lua"
)


def collect_slot_models(cursor):
    models = {}

    for slot_name, slot_bit in SLOT_BITS.items():
        cursor.execute(
            "SELECT DISTINCT MId"
            "  FROM item_equipment"
            " WHERE level BETWEEN 1 AND %s AND MId > 0 AND slot = %s"
            " ORDER BY MId",
            (MAX_GEAR_LEVEL, slot_bit),
        )
        models[slot_name] = [row[0] for row in cursor.fetchall()]

    return models


def collect_artifact_sets(cursor):
    cursor.execute(
        "SELECT jobs, MId, slot"
        "  FROM item_equipment"
        " WHERE level BETWEEN %s AND %s AND MId > 0 AND slot IN (16, 32, 64, 128, 256)",
        (ARTIFACT_MIN_LEVEL, ARTIFACT_MAX_LEVEL),
    )

    coverage = defaultdict(set)
    for jobs, model_id, slot in cursor.fetchall():
        if jobs in JOB_BITS:
            coverage[(jobs, model_id)].add(slot)

    required = set(SLOT_BITS.values())
    sets = []

    for (jobs, model_id), slots in coverage.items():
        if slots >= required:
            sets.append({"job": JOB_BITS[jobs], "model": model_id})

    sets.sort(key=lambda entry: entry["model"])

    return sets


def write_lua(slot_models, artifact_sets, path):
    lines = [
        "-----------------------------------",
        "-- XI_LIFE PlayerNPC equipment models",
        "--",
        "-- GENERATED FILE - do not edit by hand.",
        "-- Regenerate with: python -m tools.xi_life.generate_gear",
        "--",
        "-- slots: every distinct armour model at or below level {}, per slot.".format(
            MAX_GEAR_LEVEL
        ),
        "-- artifact: the level {}-{} job sets. Every piece of a set shares one model, so a".format(
            ARTIFACT_MIN_LEVEL, ARTIFACT_MAX_LEVEL
        ),
        "--           complete set is a single number applied to all five slots.",
        "-----------------------------------",
        "xi = xi or {}",
        "xi.xiLife = xi.xiLife or {}",
        "",
        "xi.xiLife.gear =",
        "{",
        "    slots =",
        "    {",
    ]

    for slot_name in ("head", "body", "hands", "legs", "feet"):
        models = slot_models[slot_name]
        lines.append("        {} = -- {} models".format(slot_name, len(models)))
        lines.append("        {")

        for index in range(0, len(models), 16):
            chunk = models[index : index + 16]
            lines.append("            " + ", ".join(str(m) for m in chunk) + ",")

        lines.append("        },")
        lines.append("")

    lines.append("    },")
    lines.append("")
    lines.append("    artifact =")
    lines.append("    {")

    for entry in artifact_sets:
        lines.append(
            "        {{ job = '{}', model = {} }},".format(entry["job"], entry["model"])
        )

    lines.append("    },")
    lines.append("}")
    lines.append("")
    lines.append("return xi.xiLife.gear")
    lines.append("")

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description="Generate XI_LIFE PlayerNPC gear models.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="report what would be generated without writing any files",
    )
    args = parser.parse_args()

    connection = db.connect()
    with connection:
        cursor = connection.cursor()
        slot_models = collect_slot_models(cursor)
        artifact_sets = collect_artifact_sets(cursor)

    print("")
    for slot_name in ("head", "body", "hands", "legs", "feet"):
        print("{:<8} {:>4} models".format(slot_name, len(slot_models[slot_name])))

    print("")
    print(
        "{} artifact sets: {}".format(
            len(artifact_sets), ", ".join(e["job"] for e in artifact_sets)
        )
    )

    missing = sorted(set(JOB_BITS.values()) - {e["job"] for e in artifact_sets})
    if missing:
        print("No complete set found for: {}".format(", ".join(missing)))

    if args.dry_run:
        print("")
        print("Dry run, nothing written.")
        return

    write_lua(slot_models, artifact_sets, LUA_OUTPUT)

    print("")
    print("Wrote {}".format(os.path.relpath(LUA_OUTPUT, db.REPO_ROOT)))


if __name__ == "__main__":
    main()
