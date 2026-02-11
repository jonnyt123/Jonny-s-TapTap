#!/usr/bin/env python3
"""Reduce notes by 50% in DragonForce Through the Fire and Flames chart files (all difficulties)."""

import json
import os

RESOURCES = os.path.join(os.path.dirname(__file__), "Resources")
BASE = "dragonforce_through_the_fire_and_flames"
DIFFICULTIES = ["easy", "medium", "hard", "extreme"]


def main():
    for diff in DIFFICULTIES:
        path = os.path.join(RESOURCES, f"{BASE}_{diff}.json")
        if not os.path.isfile(path):
            print(f"Skip (not found): {path}")
            continue
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        notes = data.get("notes", [])
        # Sort by time, then keep every other note (50% reduction)
        notes_sorted = sorted(notes, key=lambda n: (n["time"], n.get("lane", 0)))
        kept = notes_sorted[::2]  # indices 0, 2, 4, ...
        data["notes"] = kept
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"{diff}: {len(notes)} -> {len(kept)} notes ({path})")


if __name__ == "__main__":
    main()
