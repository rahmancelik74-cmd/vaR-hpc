"""Read-only, independent reconstruction of published portfolio summary values.

No engine, RNG, build or campaign is launched. Local raw records/arrays are
optional: --local additionally checks their exact bytes and reference order ranks.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PUBLIC = ROOT/"evidence/portfolio-campaign-20261025"
LOCAL = ROOT/"results/portfolio-campaign-20261025"


def read(name):
    with (PUBLIC/name).open(newline="", encoding="ascii") as stream:
        return list(csv.DictReader(stream))


def close(a, b):
    if not math.isclose(float(a), float(b), rel_tol=1e-11, abs_tol=1e-11):
        raise AssertionError((a, b))


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda:stream.read(1048576), b""): h.update(chunk)
    return h.hexdigest()


def mean_sd(values):
    mean = math.fsum(values)/len(values)
    return mean, math.sqrt(math.fsum((x-mean)**2 for x in values)/(len(values)-1))


def verify(local=False):
    protocol = json.loads((PUBLIC/"protocol-v1.json").read_text())
    frozen = json.loads((PUBLIC/"freeze-v1.json").read_text())
    for name in ("protocol-v1.json", "PROTOCOL-v1.md"):
        assert sha(PUBLIC/name) == frozen[name], name
    for item in protocol["fixtures"].values():
        assert sha(ROOT/item["path"]) == item["sha256"]
    reference = json.loads((PUBLIC/"reference.json").read_text())
    manifest = json.loads((PUBLIC/"manifest.json").read_text())
    assert reference["status"] == manifest["status"] == "complete"
    assert manifest["processes"] == 681
    assert reference["oracle_sha256"] == manifest["runner_sha256"] == sha(ROOT/"scripts/portfolio_campaign.py")
    raw_v, raw_b = read("validation-raw.csv"), read("benchmark-raw.csv")
    assert len(raw_v) == 135 and len(raw_b) == 546
    assert len({r["id"] for r in raw_v+raw_b}) == 681
    assert sum(r["phase"] == "measured" for r in raw_b) == 420
    assert sum(r["phase"] == "warmup" for r in raw_b) == 126
    for r in raw_v+raw_b:
        assert r["phase"] in ("validation", "measured", "warmup")
        assert float(r["end_to_end_ms"]) > 0
        expected_threads = int(r["config"][6:]) if r["config"].startswith("openmp") else 1
        assert int(r["threads_used"]) == expected_threads
        if local:
            path = LOCAL/"processes"/(f'{int(r["id"]):04d}.json')
            assert sha(path) == r["record_sha256"]
            native = json.loads(path.read_text())
            launch = json.loads(native["stdout"])
            assert native["probe_exit"] == launch["exit_code"] == 0 and not launch["timed_out"]
            assert launch["priority_class"] == 32 and launch["process_mask_hex"] == json.loads((PUBLIC/"machine-inventory.json").read_text())["process_mask_hex"]
            actual = json.loads(launch["stdout"])
            assert "common" not in actual["random_source"] and actual["input_mode"] == "portfolio"
            assert actual["backend"] == r["backend"] and actual["scenarios"] == int(r["scenarios"])
            assert len(actual["portfolio"]["assets"]) == int(r["assets"])
            if r["backend"] == "cuda":
                assert actual["cuda"]["mode"] == "full-device"
                count = int(r["scenarios"])*int(r["assets"])
                assert actual["cuda"]["normals_generated"] == count+count%2
                assert "diagnostics" not in actual["cuda"]
            close(actual["end_to_end_ms"], r["end_to_end_ms"])
            for i, field in enumerate(("var95", "var99")): close(actual["estimates"][i]["mc_var"], r[field])
            if r["phase"] != "validation":
                power = json.loads((PUBLIC/"machine-inventory.json").read_text())["power"]
                for stage in ("before", "after"):
                    assert all(launch[stage][key] == power[key] for key in ("ac_line_status", "battery_saver", "active_power_scheme"))
    convergence = read("convergence.csv")
    assert len(convergence) == 54
    for row in convergence:
        selected = [r for r in raw_v if all(r[k] == row[k] for k in ("fixture", "scenarios", "config"))]
        assert sorted(int(r["seed"]) for r in selected) == sorted(protocol["validation_seeds"])
        values = [float(r["var"+str(round(float(row["confidence"])*100))]) for r in selected]
        mean, sd = mean_sd(values)
        close(row["mean_var"], mean); close(row["sample_sd"], sd)
        lo, hi, target = (float(row[k]) for k in ("reference_lower", "reference_upper", "practical_target"))
        close(row["signed_error"], mean-float(row["reference"])); close(row["absolute_error"], abs(mean-float(row["reference"])))
        worst, best = max(abs(mean-lo), abs(mean-hi)), max(lo-mean, mean-hi, 0.)
        close(row["worst_error"], worst); close(row["best_error"], best)
        outcome = "pass" if worst <= target else "fail" if best > target else "inconclusive"
        if hi-lo > target: outcome = "inconclusive"
        assert row["practical"] == outcome
    benchmark = read("benchmark-summary.csv")
    assert len(benchmark) == 42
    for row in benchmark:
        selected = [r for r in raw_b if all(r[k] == row[k] for k in ("fixture", "scenarios", "config"))]
        assert sorted(int(r["repetition"]) for r in selected if r["phase"] == "measured") == list(range(10))
        assert sorted(int(r["repetition"]) for r in selected if r["phase"] == "warmup") == list(range(3))
        values = [float(r["end_to_end_ms"]) for r in selected if r["phase"] == "measured"]
        mean, sd = mean_sd(values)
        close(row["mean_ms"], mean); close(row["sample_sd_ms"], sd)
        close(row["scenarios_per_second"], int(row["scenarios"])*1000/mean)
        peers = [r for r in benchmark if r["fixture"] == row["fixture"] and r["scenarios"] == row["scenarios"]]
        serial = next(r for r in peers if r["config"] == "serial")
        best = min((r for r in peers if r["config"].startswith("openmp")), key=lambda r:float(r["mean_ms"]))
        assert row["best_openmp"] == best["config"]
        close(row["serial_speedup"], float(serial["mean_ms"])/mean)
        close(row["best_openmp_speedup"], float(best["mean_ms"])/mean)
    details = read("validation-details.csv")
    assert len(details) == 270
    for row in details:
        close(row["absolute_error"], abs(float(row["var"])-float(row["reference"])))
        not_rejected = float(row["cdf_lower"]) <= float(row["reference_empirical_cdf"]) <= float(row["cdf_upper"])
        assert row["consistency"] == ("not_rejected" if not_rejected else "rejected")
    for row in convergence:
        selected = [r for r in details if all(r[k] == row[k] for k in ("fixture", "scenarios", "config", "confidence"))]
        assert int(row["rejected_seeds"]) == sum(r["consistency"] == "rejected" for r in selected)
    if local:
        import numpy as np
        from scipy.stats import binom, beta
        for name, case in reference["cases"].items():
            path = LOCAL/"reference"/(name+".npy")
            assert sha(path) == case["array_sha256"]
            data = np.load(path, mmap_mode="r")
            for start in range(0, len(data), 250000):
                part = data[max(0, start-1):start+250000]
                assert np.all(part[1:] >= part[:-1])
            for q in case["quantiles"]:
                n, alpha = len(data), q["confidence"]
                close(q["var"], data[math.ceil(alpha*n)-1])
                close(q["lower"], data[q["lower_index"]]); close(q["upper"], data[q["upper_index"]])
                coverage = binom.cdf(q["upper_index"], n, alpha)-binom.cdf(q["lower_index"], n, alpha)
                assert coverage >= 1-.0025/6-1e-12
            for row in (r for r in details if r["fixture"] == name):
                close(row["reference_empirical_cdf"], np.searchsorted(data, float(row["var"]), side="right")/len(data))
                n = int(row["scenarios"]); k = math.ceil(float(row["confidence"])*n)
                tail = .005/540
                low, high = beta.ppf([tail, 1-tail], k, n+1-k)
                eps = math.sqrt(math.log(2/(.0025/3))/(2*len(data)))
                close(row["cdf_lower"], low-eps); close(row["cdf_upper"], high+eps)
        for name, value in manifest["artifacts"].items(): assert sha(ROOT/name) == value
    figures = json.loads((PUBLIC/"figure-data.json").read_text())
    for series in figures["runtime"]:
        for n, mean, sd in zip(series["n"], series["mean_ms"], series["sample_sd_ms"]):
            row = next(r for r in benchmark if r["fixture"] == series["fixture"] and r["config"] == series["config"] and int(r["scenarios"]) == n)
            close(mean, row["mean_ms"]); close(sd, row["sample_sd_ms"])
    for series in figures["convergence"]:
        v0 = reference["cases"][series["fixture"]]["initial_value"]
        for n, mean, sd in zip(series["n"], series["signed_error_bp"], series["sample_sd_bp"]):
            row = next(r for r in convergence if r["fixture"] == series["fixture"] and r["config"] == series["config"] and int(r["scenarios"]) == n and float(r["confidence"]) == series["confidence"])
            close(mean, float(row["signed_error"])*10000/v0); close(sd, float(row["sample_sd"])*10000/v0)
    for series in figures["speedup"]:
        for n, ratio, lower_error, upper_error in zip(series["n"], series["ratio"], series["lower_error"], series["upper_error"]):
            row = next(r for r in benchmark if r["fixture"] == series["fixture"] and int(r["scenarios"]) == n and r["config"] == "cuda")
            close(ratio, row["serial_speedup"] if series["baseline"] == "serial" else row["best_openmp_speedup"])
            baseline = "serial" if series["baseline"] == "serial" else row["best_openmp"]
            base = next(r for r in benchmark if r["fixture"] == series["fixture"] and int(r["scenarios"]) == n and r["config"] == baseline)
            a, b, sa, sb = (float(base["mean_ms"]), float(row["mean_ms"]), float(base["sample_sd_ms"]), float(row["sample_sd_ms"]))
            assert b-sb > 0, "Undefined descriptive speedup envelope"
            close(lower_error, ratio-max(0, a-sa)/(b+sb))
            close(upper_error, (a+sa)/(b-sb)-ratio)
    inventory_path = PUBLIC/"artifact-sha256.json"
    if inventory_path.exists():
        inventory = json.loads(inventory_path.read_text())
        for name, digest in inventory["package_files"].items():
            assert sha(PUBLIC/name) == digest, name
        for name, digest in inventory["hash_bound_tooling"].items():
            assert sha(ROOT/name) == digest, name
    return dict(status="passed", scope="public summary/figure arithmetic plus local record/reference array integrity" if local else "public summary/figure arithmetic; raw reference arrays and launch records not checked", native_processes=135, benchmark_processes=546, measured=420, summary_rows=42)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local", action="store_true")
    args = parser.parse_args()
    print(json.dumps(verify(args.local), indent=2))
