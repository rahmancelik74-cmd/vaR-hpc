"""Read-only baseline counter audit; never launches a GPU workload."""
import argparse
import csv
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import re

METRICS = ("dram__bytes_read.sum", "dram__bytes_write.sum", "gpu__time_duration.sum",
           "profiler__replayer_passes", "profiler__replayer_passes_type_warmup")
UNITS = ("byte", "byte", "ns", "pass", "pass")


def stage(name):
    for marker, label in (("generate_seed_pseudo", "rng-initialization"),
                          ("gen_sequenced_Philox", "rng-generation"),
                          ("losses_kernel", "simulation"),
                          ("cub::DeviceRadixSort", "radix-sort"),
                          ("quantile_kernel", "quantile-gather")):
        if marker in name:
            return label
    raise ValueError("Unclassified kernel: " + name)


def raw_integer(token):
    # Exact observed Turkish export format: '.' grouping and ',' decimal.
    if not re.fullmatch(r"(?:\d{1,3}(?:\.\d{3})+|\d+),\d+", token):
        raise ValueError("Unexpected localized metric: " + token)
    value = Decimal(token.replace(".", "").replace(",", "."))
    if value < 0 or value != value.to_integral_value():
        raise ValueError("Expected nonnegative integral metric")
    return int(value)


def project(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        units = next(reader)
        if tuple(units[m] for m in METRICS) != UNITS:
            raise ValueError("Counter units changed")
        return [dict(id=int(r["ID"]), kernel=r["Kernel Name"],
                     stage=stage(r["Kernel Name"]),
                     metrics={m: raw_integer(r[m]) for m in METRICS}) for r in reader]


def summarize(rows, mode):
    expected = {"full-device": {"rng-initialization": 1, "rng-generation": 1,
                "simulation": 1, "radix-sort": 10, "quantile-gather": 1},
                "hybrid": {"rng-initialization": 1, "rng-generation": 153,
                           "simulation": 153}}[mode]
    if [r["id"] for r in rows] != list(range(sum(expected.values()))):
        raise ValueError("Missing, reordered or duplicate kernel ID")
    groups = {}
    for row in rows:
        if row["stage"] != stage(row["kernel"]):
            raise ValueError("Stage classification mismatch")
        metrics = row["metrics"]
        if set(metrics) != set(METRICS) or any(type(v) is not int or v < 0 for v in metrics.values()):
            raise ValueError("Invalid metric values")
        if metrics[METRICS[2]] <= 0 or metrics[METRICS[3]] != 1 or metrics[METRICS[4]] != 0:
            raise ValueError("Unexpected duration, replay pass or warmup coverage")
        group = groups.setdefault(row["stage"], dict(kernels=0, read_bytes=0, write_bytes=0, duration_ns=0))
        group["kernels"] += 1
        for key, metric in zip(("read_bytes", "write_bytes", "duration_ns"), METRICS):
            group[key] += metrics[metric]
    if {k: v["kernels"] for k, v in groups.items()} != expected:
        raise ValueError("Incomplete stage coverage")
    groups["all-collected-kernels"] = {key: sum(g[key] for g in groups.values())
                                       for key in ("kernels", "read_bytes", "write_bytes", "duration_ns")}
    for group in groups.values():
        group["GBps"] = (group["read_bytes"] + group["write_bytes"]) / group["duration_ns"]
    return groups


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local-records", type=Path)
    args = parser.parse_args()
    base = Path(__file__).resolve().parent
    manifest = json.loads((base / "manifest.json").read_text(encoding="ascii"))
    for entry in manifest["selected_files"]:
        path = (base / entry["file"]).resolve()
        if base not in path.parents or hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError("Changed selected evidence: " + entry["file"])
    if args.local_records:
        for entry in manifest["local_files"]:
            path = args.local_records / entry["file"]
            if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
                raise ValueError("Changed local record: " + entry["file"])
    measured = json.loads((base / "kernel-metrics.json").read_text(encoding="ascii"))
    summary = json.loads((base / "summary.json").read_text(encoding="ascii"))
    for mode, raw in (("full-device", "full-device-raw-corrected"), ("hybrid", "hybrid-raw")):
        if args.local_records and project(args.local_records / (raw + ".stdout.txt")) != measured[mode]:
            raise ValueError("Projection differs from original raw export")
        if summarize(measured[mode], mode) != summary[mode]:
            raise ValueError("Summary differs from counters")
    print(json.dumps(dict(status="passed", full_device_kernels=14, hybrid_kernels=307,
                         local_raw_checked=bool(args.local_records), new_gpu_processes=0)))


if __name__ == "__main__":
    main()
