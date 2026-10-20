"""Read-only selected-evidence integrity; optional local convergence audit.

No engine, build, download, dependency installation or figure renderer is run.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

BASE = "b9745be08a477b3648afc8499b07fb2ae4aec165"
FIGURES = "evidence/v030-convergence-figures-20261020-v2"
INVENTORIES = (
    ("evidence/v030-primary-benchmark-windows-20261019", "artifact-sha256.json"),
    ("evidence/v030-cuda-stage-diagnostics-windows-20261019", "artifact-sha256.json"),
    (FIGURES, "selection-manifest.v2.json"),
)


def checked_child(base, name):
    path = (base / name).resolve()
    if base.resolve() not in path.parents:
        raise ValueError("Inventory path escapes its package")
    return path


def check_inventory(root, directory, name, helper):
    base = root / directory
    path = base / name
    original = helper.git_bytes(root, BASE, directory + "/" + name)
    helper.check_equal(path.read_bytes(), original, "Historical inventory bytes")
    inventory = helper.read_json(path)
    entries = inventory["selected_files"] if isinstance(inventory, dict) else inventory
    seen = set()
    for entry in entries:
        if entry["file"] in seen:
            raise ValueError("Duplicate inventory path")
        seen.add(entry["file"])
        helper.check_equal(helper.sha(checked_child(base, entry["file"])),
                           entry["sha256"], "Selected artifact " + entry["file"])
    if isinstance(inventory, dict):
        for parent in inventory["parent_manifests"]:
            helper.check_equal(helper.sha(checked_child(root, parent["path"])),
                               parent["sha256"], "Parent manifest")
        for document in inventory["tracked_release_content"]:
            content = helper.git_bytes(root, "35338cdc462aea88b37ed07a7d2b759138480f96",
                                       document["path"])
            helper.check_equal(hashlib.sha256(content).hexdigest(),
                               document["git_blob_content_sha256"], "Historical release content")
    return len(entries)


def local_convergence(root, helper):
    try:
        return helper.validate(root / "evidence/v030-convergence-windows-20261020", root)[-1]
    except FileNotFoundError as error:
        raise ValueError("Local archive dependency unavailable: " + str(error)
                         + ". Restore the exact hash-bound original results/build archive; "
                         "a new binary or private-price download is not a substitute. "
                         "See docs/reproducibility.md.") from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--local-convergence", action="store_true")
    args = parser.parse_args()
    root = args.repository.resolve()
    try:
        spec = importlib.util.spec_from_file_location("archived_figures", root / FIGURES / "convergence_figures.py")
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        counts = {directory: check_inventory(root, directory, name, helper)
                  for directory, name in INVENTORIES}
        report = {"status": "passed", "scope": "selected-public-artifact-integrity",
                  "inventory_snapshot": BASE, "verified_artifact_counts": counts,
                  "local_convergence": "not requested; raw execution provenance not reverified",
                  "new_engine_processes": 0}
        if args.local_convergence:
            report["local_convergence"] = local_convergence(root, helper)
        print(json.dumps(report, ensure_ascii=True, indent=2))
        return 0
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        message = ("Reproducibility check failed: " + str(error)
                   + ". Full Git history through " + BASE + " is required.")
        print(message.encode("ascii", "backslashreplace").decode("ascii"), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
