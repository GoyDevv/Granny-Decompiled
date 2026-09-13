#!/usr/bin/env python3
"""Audit Unity YAML GUID references before a conversion run.

The decompiled project is source-like Unity YAML. Unidot uses GUIDs to resolve
assets, and its documentation warns that missing GUID references can be hard to
spot. This audit builds a GUID->asset map from .meta files, scans text-based
Unity assets for GUID references, and emits both JSON and a human-readable
summary.
"""
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

GUID_RE = re.compile(r"\bguid:\s*([0-9a-fA-F]{32})\b")
TEXT_EXTS = {
    ".unity", ".prefab", ".mat", ".asset", ".anim", ".controller",
    ".overrideController", ".playable", ".physicsMaterial", ".guiskin",
    ".meta",
}
LFS_PREFIX = b"version https://git-lfs.github.com/spec/v1"


def iter_files(root: Path):
    yield from (p for p in root.rglob("*") if p.is_file())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--assets", default="Assets")
    ap.add_argument("--out", default="conversion/audit")
    args = ap.parse_args()

    assets = Path(args.assets).resolve()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    guid_to_path: dict[str, str] = {}
    duplicate_guids: dict[str, list[str]] = defaultdict(list)
    lfs_files: list[str] = []

    for p in iter_files(assets):
        try:
            head = p.open("rb").read(128)
        except OSError:
            continue
        if head.startswith(LFS_PREFIX):
            lfs_files.append(p.relative_to(assets).as_posix())
        if p.name.endswith(".meta"):
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            m = GUID_RE.search(text)
            if m:
                guid = m.group(1).lower()
                asset_path = p.with_suffix("")
                rel = asset_path.relative_to(assets).as_posix()
                if guid in guid_to_path and guid_to_path[guid] != rel:
                    duplicate_guids[guid].append(rel)
                else:
                    guid_to_path[guid] = rel

    references: Counter[str] = Counter()
    ref_files: dict[str, list[str]] = defaultdict(list)
    unreadable: list[str] = []

    for p in iter_files(assets):
        if p.suffix not in TEXT_EXTS:
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            unreadable.append(p.relative_to(assets).as_posix())
            continue
        for guid in GUID_RE.findall(text):
            guid = guid.lower()
            references[guid] += 1
            if len(ref_files[guid]) < 8:
                ref_files[guid].append(p.relative_to(assets).as_posix())

    missing = sorted(g for g in references if g not in guid_to_path)
    report = {
        "assets_root": str(assets),
        "meta_guid_count": len(guid_to_path),
        "referenced_guid_count": len(references),
        "missing_guid_count": len(missing),
        "missing_guids": [
            {"guid": g, "references": references[g], "files": ref_files[g]}
            for g in missing
        ],
        "duplicate_guid_count": len(duplicate_guids),
        "duplicate_guids": duplicate_guids,
        "lfs_pointer_files": lfs_files,
        "unreadable_files": unreadable,
    }

    (out / "unity-guid-audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    summary = [
        "# Unity GUID dependency audit",
        "",
        f"* Meta GUIDs: **{len(guid_to_path):,}**",
        f"* Referenced GUIDs: **{len(references):,}**",
        f"* Missing GUIDs: **{len(missing):,}**",
        f"* Duplicate GUIDs: **{len(duplicate_guids):,}**",
        f"* Git-LFS pointer files: **{len(lfs_files):,}**",
        f"* Unreadable text assets: **{len(unreadable):,}**",
        "",
    ]
    if missing:
        summary += ["## Missing GUIDs", ""]
        for g in missing[:100]:
            summary.append(f"- `{g}` referenced {references[g]} time(s): {', '.join(ref_files[g])}")
    (out / "unity-guid-audit.md").write_text("\n".join(summary) + "\n", encoding="utf-8")

    print("\n".join(summary))
    return 2 if missing or duplicate_guids or lfs_files else 0


if __name__ == "__main__":
    raise SystemExit(main())
