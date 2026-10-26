"""Independent original-byte Decimal calibration audit and modest native integration.

Does not import the production calibrator. Outputs remain private beside it.
"""
import argparse
import csv
import datetime
from decimal import Decimal, localcontext
import hashlib
import io
import json
import math
from pathlib import Path
import subprocess
import sys

TOLERANCE = Decimal("1e-12")
ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check(condition, message):
    if not condition:
        raise ValueError(message)


def audit(folder):
    data = json.loads((folder/"calibration.json").read_text())
    check(sha(folder/"portfolio.txt") == data["portfolio_sha256"], "Portfolio bytes changed")
    check(sha(folder/"request.json") == data["request_sha256"] and
          sha(folder/"calendar.json") == data["calendar_sha256"], "Request/calendar changed")
    request = json.loads((folder/"request.json").read_text())
    calendar = json.loads((folder/"calendar.json").read_text())
    first, last = (datetime.date.fromisoformat(request[k]) for k in ("start","end"))
    expected = [(first+datetime.timedelta(days=i)).isoformat()
                for i in range((last-first).days+1)
                if (first+datetime.timedelta(days=i)).weekday() < 5 and
                (first+datetime.timedelta(days=i)).isoformat() not in calendar["full_closures"]]
    check(expected == data["aligned_dates"] and data["valuation_date"] == expected[-1],
          "Independent calendar disagreement")
    check(data["asset_order"] == sorted(a["id"] for a in data["assets"]), "Asset order changed")
    check(all(a["source"]["data_kind"] == data["data_kind"] for a in data["assets"]), "Data-kind mismatch")
    request_base = Path(data["original_request_path"]).parent
    requested = {str((request_base/a["import"]).resolve()):a["quantity"] for a in request["assets"]}
    check(len(requested) == len(data["assets"]) == len(request["assets"]), "Request asset count mismatch")
    columns = []
    for asset in data["assets"]:
        source = Path(asset["import_path"])
        check(str(source) in requested and requested[str(source)] == asset["quantity"],
              "Original request holding mismatch")
        for name, digest in asset["hashes"].items():
            check(sha(source/name) == digest, "Original-byte hash changed: " + name)
        manifest = json.loads((source/"manifest.json").read_text())
        check(manifest["source_format"] == "kibot_daily", "Independent audit supports explicit Kibot daily only")
        rows = []
        for fields in csv.reader(io.StringIO((source/"raw.csv").read_bytes().decode("utf-8-sig"))):
            check(len(fields) == 6, "Invalid original daily row")
            date = datetime.datetime.strptime(fields[0],"%m/%d/%Y").date().isoformat()
            price = Decimal(fields[4])
            check(price.is_finite() and price > 0, "Invalid original Close")
            check(not rows or date > rows[-1][0], "Invalid original order/duplicate")
            rows.append((date,price))
        converted = list(csv.reader(io.StringIO((source/"prices.csv").read_text(encoding="utf-8-sig"))))
        check(converted[0] == ["date","close"], "Wrong converted header")
        converted = [(d,Decimal(p)) for d,p in converted[1:]]
        selected_import = [(d,p) for d,p in rows if manifest["requested_date_start"] <= d <= manifest["requested_date_end"]]
        check(selected_import == converted, "Original/converted prices disagree")
        selected = [(d,p) for d,p in rows if request["start"] <= d <= request["end"]]
        check([d for d,p in selected] == expected, "Original-byte alignment mismatch")
        excluded = [d for d,p in converted if not request["start"] <= d <= request["end"]]
        check(excluded == asset["excluded_dates"] and len(excluded) == asset["excluded_count"],
              "Excluded-date accounting mismatch")
        check(float(selected[-1][1]) == asset["initial_price"], "Valuation Close mismatch")
        columns.append([p for d,p in selected])
    with localcontext() as context:
        context.prec = 60
        returns = [[(p[i]/p[i-1]).ln() for i in range(1,len(p))] for p in columns]
        n, a = len(returns[0]), len(returns)
        means = [sum(r)/n for r in returns]
        cov = [[sum((returns[i][t]-means[i])*(returns[j][t]-means[j]) for t in range(n))/(n-1)
                for j in range(a)] for i in range(a)]
        scale = Decimal(str(request["days_per_year"]))
        vols = [(cov[i][i]*scale).sqrt() for i in range(a)]
        drifts = [means[i]*scale+cov[i][i]*scale/2 for i in range(a)]
        corr = [[cov[i][j]/(cov[i][i]*cov[j][j]).sqrt() for j in range(a)] for i in range(a)]
        differences = {}
        reference = dict(mean_log_returns=means,sample_covariance=cov,correlation=corr,
                         volatility_annual=vols,drift_annual=drifts,
                         horizon_years=Decimal(str(request["horizon_days"]))/scale)
        for key, values in reference.items():
            def compare(actual, expected_value):
                if isinstance(expected_value,list):
                    check(len(actual) == len(expected_value), "Reference dimension mismatch")
                    return [d for x,y in zip(actual,expected_value) for d in compare(x,y)]
                difference = abs(Decimal(str(actual))-expected_value)
                check(difference <= TOLERANCE*max(1,abs(expected_value)), "Arithmetic tolerance exceeded: " + key)
                return [float(difference)]
            differences[key] = max(compare(data[key],values))
        check(n == data["returns_count"] and n+1 == data["observations_count"], "Count mismatch")
    return dict(status="passed", data_kind=data["data_kind"],
                method="Original headerless Kibot-dialect bytes; Decimal precision 60 log ratios; two-pass covariance",
                tolerance="1e-12*max(1,abs(reference))", max_absolute_differences=differences,
                returns_count=n, calibration_sha256=sha(folder/"calibration.json"),
                auditor_sha256=sha(__file__), private_only=True)


def integrate(folder, executable, cuda):
    data = json.loads((folder/"calibration.json").read_text())
    runs = []
    for backend in (["serial","openmp","cuda"] if cuda else ["serial","openmp"]):
        args = [str(executable.resolve()),"--portfolio",str(folder/"portfolio.txt"),"10003","42",
                "--backend",backend]
        if backend == "openmp":
            args += ["--threads","4"]
        if backend == "cuda":
            args += ["--cuda-mode","full-device","--cuda-diagnostics"]
        args += ["--json"]
        result = subprocess.run(args,capture_output=True,timeout=120)
        (folder/(backend+".stdout.json")).write_bytes(result.stdout)
        (folder/(backend+".stderr.txt")).write_bytes(result.stderr)
        check(result.returncode == 0, "Backend failed: " + backend)
        record = json.loads(result.stdout)
        check(record["backend"] == backend and record["scenarios"] == 10003 and record["seed"] == "42",
              "Backend request metadata mismatch")
        check([x["confidence"] for x in record["estimates"]] == [.95,.99], "Confidence mismatch")
        check(record["portfolio"]["unit"] == data["unit"] and record["input_mode"] == "portfolio", "Unit/mode mismatch")
        check(record["portfolio"]["horizon_years"] == data["horizon_years"], "Horizon mismatch")
        check(record["portfolio"]["initial_value"] == sum(a["quantity"]*a["initial_price"] for a in data["assets"]),
              "Initial portfolio value mismatch")
        check(record["portfolio"]["correlation_row_major"] == [x for row in data["correlation"] for x in row],
              "Correlation serialization mismatch")
        for i, asset in enumerate(record["portfolio"]["assets"]):
            for key in ("id","quantity","initial_price"):
                check(asset[key] == data["assets"][i][key], "Asset identity/value mismatch")
            for key in ("drift_annual","volatility_annual"):
                check(asset[key] == data[key][i], "Calibrated model serialization mismatch")
        check(len(record["portfolio"]["assets"]) == len(data["assets"]), "Asset count mismatch")
        check(all(x["analytical_var"] is None and x["signed_error"] is None for x in record["estimates"]),
              "Unexpected portfolio analytical reference")
        native_rng = {"serial":"mt19937_64/std::normal_distribution",
                      "openmp":"block4096/splitmix64/mt19937_64/std::normal_distribution",
                      "cuda":"cuRAND/PHILOX4_32_10/normal-double"}
        check(record["random_source"] == native_rng[backend], "Native RNG metadata mismatch")
        check(all(math.isfinite(x["mc_var"]) for x in record["estimates"]), "Nonfinite VaR output")
        if backend == "openmp":
            check(record["requested_threads"] == 4 and record["threads_used"] > 0, "OpenMP metadata mismatch")
        if backend == "cuda":
            check(record["cuda"]["mode"] == "full-device" and not record["cuda"]["host_sorting_used"]
                  and record["cuda"]["cub_version"] == 300403, "CUDA mode/library mismatch")
        runs.append(dict(backend=backend,status="passed",stdout_sha256=sha(folder/(backend+".stdout.json")),
                         stderr_sha256=sha(folder/(backend+".stderr.txt")),command=args))
    return dict(status="passed", data_kind=data["data_kind"],
                purpose="Modest native integration, not benchmark/statistical acceptance",
                executable=str(executable.resolve()), executable_sha256=sha(executable),
                process_policy="One fresh process per backend; no repeated timing samples",
                cuda_status="passed" if cuda else "not_requested",runs=runs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory",type=Path)
    parser.add_argument("--executable",type=Path)
    parser.add_argument("--cuda",action="store_true")
    args = parser.parse_args()
    try:
        folder = args.directory.resolve()
        check(folder.is_relative_to(ROOT/"results") and folder != ROOT/"results", "Private results directory required")
        names = ["independent-audit.json"] + (["integration.json","serial.stdout.json","serial.stderr.txt",
                 "openmp.stdout.json","openmp.stderr.txt"] if args.executable else [])
        if args.cuda:
            check(args.executable is not None, "CUDA requires executable")
            names += ["cuda.stdout.json","cuda.stderr.txt"]
        check(all(not (folder/name).exists() for name in names), "Refusing to overwrite existing evidence")
        report = audit(folder)
        (folder/"independent-audit.json").write_text(json.dumps(report,indent=2)+"\n",encoding="ascii")
        if args.executable:
            integration = integrate(folder,args.executable,args.cuda)
            (folder/"integration.json").write_text(json.dumps(integration,indent=2)+"\n",encoding="ascii")
        print("Independent calibration and requested integration checks passed; private outputs retained")
        return 0
    except (ValueError,KeyError,TypeError,OSError,ArithmeticError,subprocess.SubprocessError) as exc:
        print("Verification error: " + str(exc),file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
