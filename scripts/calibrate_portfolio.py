"""Strict offline historical portfolio calibration; standard library only."""
import argparse
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TOKEN = re.compile(r"[A-Z0-9.\-]{1,24}\Z")
NUMBER = re.compile(r"[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?\Z")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_json(path):
    def duplicate(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    return json.loads(Path(path).read_text(encoding="utf-8-sig"),
                      object_pairs_hook=duplicate,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Nonfinite JSON")))


def date(value):
    require(isinstance(value, str) and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value),
            "Expected ISO date")
    return dt.date.fromisoformat(value)


def positive(value):
    require(type(value) in (float, int) and math.isfinite(value) and value > 0,
            "Expected finite positive number")
    return float(value)


def sessions(calendar, start, end):
    require(date(calendar["coverage_start"]) <= start <= end <= date(calendar["coverage_end"]),
            "Interval outside bounded calendar coverage")
    require(calendar["market"] == "Nasdaq US cash equities" and
            calendar["date_basis"] == "America/New_York session date", "Incompatible calendar")
    closures = [date(x) for x in calendar["full_closures"]]
    early = [date(x) for x in calendar["early_closes"]]
    require(len(set(closures)) == len(closures) and len(set(early)) == len(early)
            and not set(early).intersection(closures), "Duplicate/conflicting calendar dates")
    require(all(x.weekday() < 5 and date(calendar["coverage_start"]) <= x <=
                date(calendar["coverage_end"]) for x in closures + early), "Invalid calendar session")
    result = []
    day = start
    while day <= end:
        if day.weekday() < 5 and day not in closures:
            result.append(day.isoformat())
        day += dt.timedelta(days=1)
    require(len(result) >= 3, "Insufficient calendar observations")
    return result


def prices(path):
    text = Path(path).read_bytes().decode("utf-8-sig")
    require(not re.search(r"\r(?!\n)", text), "Bare CR is unsupported")
    lines = text.replace("\r\n", "\n").split("\n")
    if lines[-1] == "":
        lines.pop()
    require(lines and lines[0] == "date,close", "Expected date,close CSV")
    rows = []
    for line in lines[1:]:
        fields = line.split(",")
        require(len(fields) == 2, "Malformed price row")
        day, value = fields
        date(day)
        require(NUMBER.fullmatch(value) is not None, "Malformed price")
        value = positive(float(value))
        require(not rows or rows[-1][0] < day, "Duplicate or unsorted dates")
        rows.append((day, value))
    require(len(rows) >= 3, "Insufficient price observations")
    return rows


def statistics(columns, days_per_year, horizon_days):
    """Shared observations, multivariate Welford; no pairwise deletion."""
    a = len(columns)
    require(2 <= a <= 5 and len({len(c) for c in columns}) == 1 and len(columns[0]) >= 3,
            "Need 2..5 equally aligned assets and at least three prices")
    scale, horizon = positive(days_per_year), positive(horizon_days)
    require(math.isfinite(1/scale) and math.isfinite(horizon/scale) and horizon/scale > 0,
            "Invalid annualization or horizon conversion")
    for column in columns:
        for p in column:
            positive(p)
    means = [0.0] * a
    m2 = [[0.0] * a for _ in range(a)]
    n = 0
    for t in range(1, len(columns[0])):
        r = [math.log(c[t]) - math.log(c[t-1]) for c in columns]
        n += 1
        delta = [r[i] - means[i] for i in range(a)]
        means = [means[i] + delta[i] / n for i in range(a)]
        # Symmetric rank-one online covariance update.
        for i in range(a):
            for j in range(i+1):
                m2[i][j] += delta[i] * delta[j] * (n-1) / n
    cov = [[m2[max(i,j)][min(i,j)] / (n-1) for j in range(a)] for i in range(a)]
    variances = [cov[i][i] for i in range(a)]
    require(all(math.isfinite(x) and x > 0 for x in variances), "Zero/nonfinite variance")
    vol = [math.sqrt(v * scale) for v in variances]
    mu = [means[i] * scale + 0.5 * variances[i] * scale for i in range(a)]
    corr = [[cov[i][j] / (math.sqrt(variances[i]) * math.sqrt(variances[j]))
             if i != j else 1.0 for j in range(a)] for i in range(a)]
    flat = means + vol + mu + [horizon/scale] + [x for row in cov+corr for x in row]
    require(all(math.isfinite(x) for x in flat), "Nonfinite calibration output")
    require(all(-1 <= x <= 1 for row in corr for x in row), "Correlation out of bounds")
    factor = [[0.0] * a for _ in range(a)]
    for i in range(a):
        for j in range(i+1):
            pivot = corr[i][j] - sum(factor[i][k]*factor[j][k] for k in range(j))
            if i == j:
                require(pivot > 1e-14, "Singular or unsupported near-singular correlation")
                factor[i][j] = math.sqrt(pivot)
            else:
                factor[i][j] = pivot / factor[j][j]
    require(all(abs(sum(factor[i][k]*factor[j][k] for k in range(a))-corr[i][j]) <= 2e-12
                for i in range(a) for j in range(a)), "Cholesky reconstruction failed")
    return dict(returns_count=n, mean_log_returns=means, sample_covariance=cov,
                correlation=corr, drift_annual=mu, volatility_annual=vol,
                horizon_years=horizon/scale)


def calibrate(request_path):
    request_path = Path(request_path).resolve()
    request = read_json(request_path)
    base = request_path.parent
    require(request["frequency"] == "daily", "Only daily equity observations supported")
    expected = sessions(read_json(base/request["calendar"]), date(request["start"]), date(request["end"]))
    require(2 <= len(request["assets"]) <= 5, "Need 2..5 assets")
    assets = []
    for item in request["assets"]:
        folder = (base/item["import"]).resolve()
        manifest = read_json(folder/"manifest.json")
        paths = {"raw.csv":"raw_sha256", "source-metadata.json":"source_metadata_sha256",
                 "prices.csv":"converted_sha256"}
        for name, key in paths.items():
            require(digest(folder/name) == manifest[key], "Import exact-byte hash mismatch: " + name)
        metadata = read_json(folder/"source-metadata.json")
        require(metadata == manifest["source"], "Import source metadata mismatch")
        require(metadata["local_use_verified"] is True and metadata["data_kind"] in
                ("historical_provider", "artificial_fixture"), "Unverified source/local use")
        for key in ("source_name", "source_url", "price_policy_url", "reuse_policy_url",
                    "local_reuse_conditions", "retrieved_utc", "currency_basis_url", "close_definition"):
            require(isinstance(metadata.get(key), str) and metadata[key].strip(), "Missing provenance: " + key)
        require(TOKEN.fullmatch(metadata["symbol"]) is not None and
                re.fullmatch(r"[A-Z]{3}", metadata["currency"]), "Invalid identity/currency")
        require(metadata["price_adjustment_policy"] in ("unadjusted", "split_adjusted",
                "split_and_dividend_adjusted"), "Unknown adjustment policy")
        require(manifest["selected_price_field"] in ("Close", "close") and
                manifest["invalid_rows_discarded"] == 0 and manifest["observations_filled"] == 0,
                "Unsupported import transformation")
        rows = prices(folder/"prices.csv")
        selected = [(d,p) for d,p in rows if request["start"] <= d <= request["end"]]
        require([d for d,p in selected] == expected,
                "Missing/unexpected sessions or incompatible coverage: " + metadata["symbol"])
        excluded = [d for d,p in rows if not request["start"] <= d <= request["end"]]
        assets.append(dict(id=metadata["symbol"], quantity=positive(item["quantity"]),
                           initial_price=selected[-1][1], source=metadata, import_path=str(folder),
                           hashes={name:digest(folder/name) for name in (*paths, "manifest.json")},
                           excluded_dates=excluded, excluded_count=len(excluded),
                           values=[p for d,p in selected]))
    assets.sort(key=lambda x:x["id"])
    require(len({a["id"] for a in assets}) == len(assets), "Duplicate asset identity")
    for key in ("currency", "source_name", "price_adjustment_policy", "close_definition", "data_kind"):
        require(len({a["source"][key] for a in assets}) == 1, "Incompatible " + key)
    stats = statistics([a.pop("values") for a in assets], request["days_per_year"], request["horizon_days"])
    holdings = [a["initial_price"]*a["quantity"] for a in assets]
    require(all(math.isfinite(v) and v > 0 for v in holdings) and math.isfinite(sum(holdings)),
            "Initial value overflow or underflow")
    kind = assets[0]["source"]["data_kind"]
    purpose = ("Historical calibration integration, not statistical acceptance" if kind == "historical_provider"
               else "Synthetic fixture calibration; not historical evidence")
    result = dict(schema_version=1, purpose=purpose, data_kind=kind,
                  alignment="strict_common_window_exact_sessions", aligned_dates=expected,
                  valuation_date=expected[-1], observations_count=len(expected),
                  asset_order=[a["id"] for a in assets], assets=assets,
                  unit=assets[0]["source"]["currency"], days_per_year=request["days_per_year"],
                  horizon_days=request["horizon_days"], dt_years=1/positive(request["days_per_year"]),
                  covariance_denominator="n-1 shared aligned returns", **stats)
    lines = [f"portfolio-v1 {result['unit']} {stats['horizon_years']:.17g} {len(assets)}"]
    for i, asset in enumerate(assets):
        lines.append("{} {:.17g} {:.17g} {:.17g} {:.17g}".format(asset["id"], asset["quantity"],
                     asset["initial_price"], stats["drift_annual"][i], stats["volatility_annual"][i]))
    lines += [" ".join(format(x,".17g") for x in row) for row in stats["correlation"]]
    return result, "\n".join(lines)+"\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        out = args.output.resolve()
        require(out.is_relative_to(ROOT/"results") and out != ROOT/"results" and not out.exists(),
                "Output must be a new directory under ignored results")
        result, text = calibrate(args.request)
        result["created_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
        result["source_revision"] = subprocess.check_output(["git","rev-parse","HEAD"], cwd=ROOT, text=True).strip()
        result["git_dirty"] = bool(subprocess.check_output(["git","status","--porcelain"], cwd=ROOT))
        result["tool_sha256"] = digest(__file__)
        result["request_sha256"] = digest(args.request)
        result["original_request_path"] = str(args.request.resolve())
        request = read_json(args.request)
        calendar = args.request.resolve().parent/request["calendar"]
        result["calendar_sha256"] = digest(calendar)
        out.mkdir(parents=True)
        (out/"request.json").write_bytes(args.request.read_bytes())
        (out/"calendar.json").write_bytes(calendar.read_bytes())
        (out/"portfolio.txt").write_bytes(text.encode("ascii"))
        result["portfolio_sha256"] = digest(out/"portfolio.txt")
        (out/"calibration.json").write_text(json.dumps(result,indent=2,allow_nan=False)+"\n",encoding="ascii")
        print("Calibration saved privately; portfolio hybrid remains unsupported")
        return 0
    except (ValueError, KeyError, TypeError, OSError, OverflowError) as exc:
        print("Calibration error: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
