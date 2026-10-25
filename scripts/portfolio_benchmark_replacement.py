"""One predeclared complete benchmark replacement; retain the invalidated attempt.

Reference/native validation are reused unchanged, with their original identities.
No metadata formatting, reference calculation, tests or plotting overlaps timing.
"""
import argparse
import csv
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
from datetime import datetime, timezone

import portfolio_campaign as c

PARENT = c.PUBLIC
ORIGINAL_LOCAL = c.LOCAL
PUBLIC = PARENT/"benchmark-replacement-v1"
LOCAL = ORIGINAL_LOCAL/"benchmark-replacement-v1"


def run():
    protocol = c.frozen()
    PUBLIC.mkdir(exist_ok=False); LOCAL.mkdir(exist_ok=False)
    records = LOCAL/"processes"; records.mkdir()
    for name in ("protocol-v1.json", "PROTOCOL-v1.md", "freeze-v1.json", "reference.json", "oracle-checks.json", "validation-raw.csv"):
        shutil.copyfile(PARENT/name, PUBLIC/name)
    for i in range(1, 136):
        shutil.copyfile(ORIGINAL_LOCAL/"processes"/(f"{i:04d}.json"), records/(f"{i:04d}.json"))
    env = c.environment()
    exe, probe = c.BUILD/"mc_var.exe", c.BUILD/"mc_cpu_probe.exe"
    original = c.snapshot()
    previous = c.load(PARENT/"manifest.json")
    assert original == previous["source_snapshot"]
    for name, digest in previous["artifacts"].items(): assert c.sha(c.ROOT/name) == digest
    inventory = json.loads(subprocess.check_output([str(probe), "--inventory"], env=env))
    c.save(PUBLIC/"machine-inventory.json", inventory)
    shutil.copyfile(PARENT/"build-environment.json", PUBLIC/"build-environment.json")
    manifest = dict(previous)
    manifest.update(status="running", started_utc=datetime.now(timezone.utc).isoformat(), errors=[],
        process_policy=protocol["benchmark"]["process"],
        replacement_reason="Original benchmark overlapped a CPU-intensive metadata serialization by the executor. Invalidate the entire first timing attempt; preserve every sample. This is the single complete replacement permitted by protocol v1.",
        benchmark_runner_sha256=c.sha(__file__), runner_sha256=c.sha(c.__file__),
        reference_arrays_local_root="results/portfolio-campaign-20261025/reference",
        validation_records_reused=135, executed_in_this_attempt=0,
        validation_origin="../validation-raw.csv; original native validation completed before the interfering operation; exact record copies, same binary",
        git_status=subprocess.check_output(["git", "status", "--short"], text=True).splitlines(),
        gpu_observations=[c.gpu_observation()])
    c.save(PUBLIC/"manifest.json", manifest)
    number = 135
    fields = list(c.read_rows("benchmark-raw.csv")[0])
    try:
        with (PUBLIC/"benchmark-raw.csv").open("x", newline="", encoding="ascii") as stream:
            writer = csv.DictWriter(stream, fields); writer.writeheader()
            for name in protocol["benchmark"]["fixtures"]:
                for n in protocol["scenario_grid"]:
                    manifest["gpu_observations"].append(c.gpu_observation())
                    for phase, count in (("warmup", 3), ("measured", 10)):
                        for repetition in range(count):
                            configs = protocol["benchmark"]["configurations"][:]
                            if repetition % 2: configs.reverse()
                            shift = 3*repetition % 7
                            for config in configs[shift:]+configs[:shift]:
                                number += 1
                                backend = "openmp" if config.startswith("openmp") else config
                                args = [str(exe), "--portfolio", protocol["fixtures"][name]["path"], str(n), "42", "--backend", backend]
                                if backend == "openmp": args += ["--threads", config[6:]]
                                if backend == "cuda": args += ["--cuda-mode", "full-device"]
                                args += ["--json"]
                                utc = datetime.now(timezone.utc).isoformat()
                                process = subprocess.run([str(probe), "--run-timeout", "120000", inventory["process_mask_hex"], *args],
                                                         env=env, capture_output=True, timeout=135)
                                path = records/(f"{number:04d}.json")
                                c.save(path, dict(utc=utc, command=args, probe_exit=process.returncode,
                                    stdout=process.stdout.decode(errors="replace"), stderr=process.stderr.decode(errors="replace")))
                                if process.returncode: raise RuntimeError("Replacement launcher failed")
                                launch = json.loads(process.stdout)
                                if launch["exit_code"] or launch["timed_out"] or launch["stderr"]:
                                    raise RuntimeError("Replacement native process failed")
                                for stage in ("before", "after"):
                                    if c.power_key(launch[stage]) != c.power_key(inventory["power"]):
                                        raise RuntimeError("Replacement power conditions changed")
                                result = json.loads(launch["stdout"])
                                assert result["backend"] == backend and "common" not in result["random_source"]
                                if backend == "openmp": assert result["threads_used"] == int(config[6:])
                                writer.writerow(dict(id=number, fixture=name, assets=len(result["portfolio"]["assets"]), scenarios=n,
                                    config=config, backend=backend, seed=42, phase=phase, repetition=repetition,
                                    end_to_end_ms=result["end_to_end_ms"], threads_used=result["threads_used"],
                                    var95=result["estimates"][0]["mc_var"], var99=result["estimates"][1]["mc_var"], record_sha256=c.sha(path)))
                                stream.flush(); time.sleep(.1)
                    print("replacement benchmark", name, n, flush=True)
        assert number == 681 and c.snapshot() == original
        for name, digest in previous["artifacts"].items(): assert c.sha(c.ROOT/name) == digest
        manifest.update(status="complete", processes=681, executed_in_this_attempt=546)
    except BaseException as error:
        manifest["status"] = "failed"; manifest["errors"].append(repr(error))
        raise
    finally:
        manifest["gpu_observations"].append(c.gpu_observation())
        manifest["finished_utc"] = datetime.now(timezone.utc).isoformat()
        c.save(PUBLIC/"manifest.json", manifest)


def analyze():
    c.PUBLIC = PUBLIC
    # Reference arrays are reused read-only; no additional reference sampling.
    c.LOCAL = ORIGINAL_LOCAL
    c.analyze()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("run", "analyze"))
    args = parser.parse_args()
    os.chdir(c.ROOT)
    {"run":run, "analyze":analyze}[args.action]()
