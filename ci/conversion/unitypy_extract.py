#!/usr/bin/env python3
"""Best-effort UnityPy extraction baseline for side-by-side comparison.

Exports Texture2D as PNG and Mesh as OBJ from serialized Unity asset files.
This intentionally does not try to recreate the Unity scene; it is the raw
asset baseline used to determine whether missing geometry/textures originate in
the source or in a scene converter.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import UnityPy


LOAD_EXTS = {
    ".assets", ".sharedAssets", ".resource", ".resS", ".bundle", ".unity3d",
    ".assetbundle",
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", default="Assets")
    ap.add_argument("--output", default="conversion/unitypy")
    args = ap.parse_args()

    src = Path(args.input)
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    textures = out / "textures"
    meshes = out / "meshes"
    textures.mkdir(exist_ok=True)
    meshes.mkdir(exist_ok=True)

    stats = {"files_loaded": 0, "textures": 0, "meshes": 0, "errors": []}
    seen = set()

    for path in src.rglob("*"):
        if not path.is_file() or path.suffix not in LOAD_EXTS:
            continue
        try:
            env = UnityPy.load(str(path))
            stats["files_loaded"] += 1
        except Exception as exc:
            stats["errors"].append({"file": str(path), "error": repr(exc)})
            continue

        for obj in env.objects:
            try:
                if obj.type.name == "Texture2D":
                    data = obj.read()
                    name = data.m_Name or f"texture_{obj.path_id}"
                    key = ("tex", path.as_posix(), obj.path_id)
                    if key in seen:
                        continue
                    seen.add(key)
                    safe = "_".join(name.split()) or f"texture_{obj.path_id}"
                    data.image.save(textures / f"{safe}_{obj.path_id}.png")
                    stats["textures"] += 1
                elif obj.type.name == "Mesh":
                    data = obj.read()
                    name = data.m_Name or f"mesh_{obj.path_id}"
                    key = ("mesh", path.as_posix(), obj.path_id)
                    if key in seen:
                        continue
                    seen.add(key)
                    safe = "_".join(name.split()) or f"mesh_{obj.path_id}"
                    (meshes / f"{safe}_{obj.path_id}.obj").write_text(data.export(), encoding="utf-8")
                    stats["meshes"] += 1
            except Exception as exc:
                stats["errors"].append({"file": str(path), "path_id": obj.path_id, "type": obj.type.name, "error": repr(exc)})

    (out / "report.json").write_text(json.dumps(stats, indent=2), encoding="utf-8")
    summary = (
        f"UnityPy baseline: loaded {stats['files_loaded']} serialized files, "
        f"exported {stats['textures']} textures and {stats['meshes']} meshes, "
        f"with {len(stats['errors'])} errors."
    )
    (out / "summary.txt").write_text(summary + "\n", encoding="utf-8")
    print(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
