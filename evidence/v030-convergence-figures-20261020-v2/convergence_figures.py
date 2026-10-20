"""Offline convergence figures from hash-bound, existing synthetic evidence."""

import argparse
import csv
import hashlib
import json
import math
import os
from pathlib import Path, PureWindowsPath
import shutil
import statistics
import sys
import subprocess

ENGINES = ("serial", "openmp", "full-device", "hybrid")
LABELS = {"serial": "Serial", "openmp": "OpenMP (4 threads)",
          "full-device": "CUDA full-device", "hybrid": "CUDA hybrid"}
NS = (10_000, 100_000, 1_000_000, 10_000_000)
SEEDS = ("42", "123", "456", "789", "2026")
ALPHAS = (0.95, 0.99)
COLORS = ("#0072B2", "#009E73", "#D55E00", "#CC79A7")
MARKERS = ("o", "s", "^", "D")
STYLES = ("-", "-", "-", "--")
SEED_COLORS = ("#0072B2", "#D55E00", "#009E73", "#CC79A7", "#444444")
TOLERANCE = 2e-12


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_csv(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def close(actual, expected, label):
    actual, expected = float(actual), float(expected)
    if not math.isfinite(actual) or not math.isfinite(expected):
        raise ValueError(f"Nonfinite {label}")
    if abs(actual - expected) > TOLERANCE * max(1.0, abs(expected)):
        raise ValueError(f"Mismatch {label}: {actual!r} vs {expected!r}")


def check_equal(actual, expected, label):
    if actual != expected:
        raise ValueError(f"Mismatch {label}: {actual!r} vs {expected!r}")


def git_bytes(root, revision, path):
    return subprocess.check_output(
        ["git", "-C", str(root), "show", f"{revision}:{path}"], stderr=subprocess.PIPE)


def resolve_recorded_path(root, recorded, recorded_root):
    """Resolve only the recorded repository prefix; never change stored JSON."""
    path = PureWindowsPath(recorded)
    if path.is_absolute():
        relative = path.relative_to(PureWindowsPath(recorded_root))
    else:
        relative = path
    if ".." in relative.parts:
        raise ValueError("Recorded path escapes repository")
    return root.joinpath(*relative.parts)


def verify_delivery_manifest(source, root, policy_path=None):
    policy_path = policy_path or Path(__file__).with_name("provenance-policy.json")
    policy = read_json(policy_path)
    check_equal(policy["schema_version"], 2, "provenance policy schema")
    manifest_path = source / "delivery-manifest.json"
    check_equal(sha(manifest_path), policy["parent_manifest_sha256"], "parent manifest bytes")
    archived = git_bytes(root, policy["snapshot_revision"], policy["parent_manifest_repository_path"])
    check_equal(hashlib.sha256(archived).hexdigest(), policy["parent_manifest_sha256"],
                "parent manifest at evidence commit")
    delivery = read_json(manifest_path)
    documents = policy["historical_documents"]
    # This exact allowlist is descriptive history, never a numerical-input exemption.
    check_equal(set(documents), {"docs/project-state.md", "docs/convergence.md"}, "historical roles")
    verified, historical, seen = [], [], set()
    for artifact in delivery["artifacts"]:
        recorded = artifact["path"]
        if recorded in seen:
            raise ValueError("Duplicate delivery artifact")
        seen.add(recorded)
        if recorded in documents:
            snapshot = policy_path.parent / documents[recorded]
            check_equal(sha(snapshot), artifact["sha256"], f"historical raw bytes {recorded}")
            blob = git_bytes(root, policy["snapshot_revision"], recorded)
            # Git text conversion is a separate content comparison, NOT hash normalization.
            check_equal(snapshot.read_bytes().replace(b"\r\n", b"\n"), blob,
                        f"historical Git content {recorded}")
            historical.append({"recorded_path": recorded, "snapshot_sha256": sha(snapshot),
                               "git_blob_sha256": hashlib.sha256(blob).hexdigest(),
                               "snapshot_revision": policy["snapshot_revision"]})
        else:
            path = resolve_recorded_path(root, recorded, delivery["actual_repository_root"])
            check_equal(sha(path), artifact["sha256"], f"delivery hash {recorded}")
            verified.append({"recorded_path": recorded, "resolved_path": str(path),
                             "sha256": artifact["sha256"]})
    check_equal(set(documents).issubset(seen), True, "historical documents present")
    return delivery, {"historical_documents": historical, "current_artifacts": verified,
                      "policy_sha256": sha(policy_path),
                      "parent_manifest_sha256": sha(manifest_path)}


def verify_normalization(row, reference, initial_value, signed_error):
    close(row["error_over_v0"], signed_error / initial_value, "error/V0")
    if abs(reference) >= 0.01 * initial_value:
        close(row["relative_error"], abs(signed_error) / abs(reference), "relative error")
        check_equal(row["relative_status"], "available", "relative status")
    else:
        check_equal(row["relative_error"], "N/A", "near-zero relative error")
        check_equal(row["relative_status"], "N/A: near-zero reference", "near-zero status")


def positive_log_points(xs, ys):
    if len(xs) != len(ys) or any(y < 0 or not math.isfinite(y) for y in ys):
        raise ValueError("Invalid nonnegative log-axis values")
    return [y if y > 0 else math.nan for y in ys], [x for x, y in zip(xs, ys) if y == 0]


def independent_fixture(path):
    rows = read_csv(path)
    prices = [float(row["close"]) for row in rows]
    dates = [row["date"] for row in rows]
    if len(rows) < 3 or dates != sorted(set(dates)):
        raise ValueError("Malformed fixture dates/count")
    if any(not math.isfinite(p) or p <= 0 for p in prices):
        raise ValueError("Malformed fixture prices")
    returns = [math.log(b / a) for a, b in zip(prices, prices[1:])]
    mean = math.fsum(returns) / len(returns)
    variance = math.fsum((r - mean) ** 2 for r in returns) / (len(returns) - 1)
    sigma = math.sqrt(variance * 252)
    mu = mean * 252 + 0.5 * sigma * sigma
    horizon = 10 / 252
    refs = {}
    for alpha, z in zip(ALPHAS, (-1.6448536269514729, -2.3263478740408408)):
        refs[alpha] = prices[-1] * (1 - math.exp(
            (mu - 0.5 * sigma * sigma) * horizon + sigma * math.sqrt(horizon) * z))
    return prices[-1], refs


def validate(source, root):
    delivery, provenance = verify_delivery_manifest(source, root)
    check_equal(delivery["tested_source_revision"],
                "b5f1a0f5b72bca8f1f21555236d938501f7faee8", "tested source")
    for name in ("independent-audit.json", "closure-audit.json"):
        check_equal(read_json(source / name)["status"], "passed", name)
    analysis = read_json(source / "analysis.json")
    check_equal((analysis["complete"], analysis["run_count"], analysis["value_count"]),
                (True, 80, 160), "coverage")
    check_equal(analysis["missing"], [], "missing matrix")
    per_seed = read_csv(source / "per-seed.csv")
    summaries = read_csv(source / "summary.csv")
    acceptance = read_csv(source / "acceptance-10m.csv")
    check_equal((len(per_seed), len(summaries), len(acceptance)), (160, 32, 8), "row counts")
    fixture = root / "data" / "synthetic_prices.csv"
    check_equal(sha(fixture),
                "8dbb7c73e6ad48cb8c8c175aff6684d2a0433e5f08424ec7ea1e69037bb36210", "fixture hash")
    v0, independent_refs = independent_fixture(fixture)
    refs = {float(r["confidence"]): float(r["analytical_var"])
            for r in analysis["fixture"]["references"]}
    for alpha in ALPHAS:
        close(refs[alpha], independent_refs[alpha], "independent reference")
    values = {}
    zeros = {}
    for row in per_seed:
        key = (row["engine"], int(row["scenarios"]), row["seed"], float(row["confidence"]))
        if key in values:
            raise ValueError(f"Duplicate seed key {key}")
        x = float(row["mc_var"])
        e = x - refs[key[3]]
        close(row["analytical_var"], refs[key[3]], "per-seed reference")
        close(row["signed_error"], e, "per-seed signed error")
        close(row["absolute_error"], abs(e), "per-seed absolute error")
        verify_normalization(row, refs[key[3]], v0, e)
        check_equal(row["input_sha256"], sha(fixture), "record input hash")
        values[key] = row
    expected = {(e, n, s, a) for e in ENGINES for n in NS for s in SEEDS for a in ALPHAS}
    check_equal(set(values), expected, "complete per-seed keys")
    groups = {}
    for row in summaries:
        key = (row["engine"], int(row["scenarios"]), float(row["confidence"]))
        if key in groups:
            raise ValueError(f"Duplicate group {key}")
        check_equal((row["seed_count"], row["complete"]), ("5", "True"), "complete group")
        xs = [float(values[(key[0], key[1], s, key[2])]["mc_var"]) for s in SEEDS]
        errors = [x - refs[key[2]] for x in xs]
        mean = math.fsum(xs) / 5
        calculated = {
            "mean_var": mean,
            "signed_error_of_mean": mean - refs[key[2]],
            "absolute_error_of_mean": abs(mean - refs[key[2]]),
            "sample_stddev": statistics.stdev(xs),
            "descriptive_mae": math.fsum(abs(e) for e in errors) / 5,
            "descriptive_rmse": math.sqrt(math.fsum(e * e for e in errors) / 5),
        }
        for field, result in calculated.items():
            close(row[field], result, field)
            zeros[field] = zeros.get(field, 0) + (float(row[field]) == 0)
        close(row["analytical_var"], refs[key[2]], "summary reference")
        verify_normalization(row, refs[key[2]], v0, calculated["signed_error_of_mean"])
        groups[key] = row
    check_equal(set(groups), {(e, n, a) for e in ENGINES for n in NS for a in ALPHAS}, "group keys")
    accept = {}
    for row in acceptance:
        key = row["engine"], float(row["confidence"])
        if key in accept:
            raise ValueError("Duplicate acceptance row")
        group = groups[(key[0], 10_000_000, key[1])]
        allowed = 0.01 * max(abs(refs[key[1]]), 0.01 * v0)
        error = float(group["absolute_error_of_mean"])
        close(row["allowed_error"], allowed, "acceptance allowed error")
        close(row["absolute_error_of_mean"], error, "acceptance mean error")
        check_equal(row["passed"], str(error <= allowed), "acceptance status")
        check_equal((row["seed_count"], row["scenarios"]), ("5", "10000000"), "acceptance group")
        accept[key] = row
    check_equal(set(accept), {(e, a) for e in ENGINES for a in ALPHAS}, "acceptance keys")
    return analysis, values, groups, accept, {
        "status": "passed", "delivery_hashes_verified": len(delivery["artifacts"]),
        "provenance": provenance,
        "per_seed_rows": 160, "summary_groups": 32, "separate_acceptance_rows": 8,
        "independent_reference": independent_refs, "statistics_tolerance": TOLERANCE,
        "zero_group_metrics": zeros,
        "method": "Independent fixture log returns/two-pass variance; fsum means, sample SD, MAE, RMSE and unchanged 10M acceptance",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root, out = args.repository.resolve(), args.output.resolve()
    source = root / "evidence" / "v030-convergence-windows-20261020"
    if out.exists():
        raise ValueError("Use a new output directory; existing evidence is never overwritten")
    if root / "results" not in out.parents:
        raise ValueError("Output must be below the repository ignored results directory")
    out.mkdir(parents=True)
    os.environ.setdefault("MPLCONFIGDIR", str(out / "matplotlib-config"))
    os.environ.setdefault("MPLBACKEND", "Agg")
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.backends.backend_pdf import PdfPages
    from matplotlib.ticker import FuncFormatter, NullFormatter
    matplotlib.rcParams.update({
        "font.family": "DejaVu Sans", "font.size": 10, "axes.titlesize": 12,
        "axes.labelsize": 10, "legend.fontsize": 9, "axes.spines.top": False,
        "axes.spines.right": False, "svg.fonttype": "none", "pdf.fonttype": 42,
        "savefig.facecolor": "white", "figure.facecolor": "white", "axes.axisbelow": True,
    })
    required = ("analysis.json", "per-seed.csv", "summary.csv", "acceptance-10m.csv",
                "independent-audit.json", "closure-audit.json", "delivery-manifest.json")
    original_hashes = {str(source / name): sha(source / name) for name in required}
    original_hashes[str(Path(__file__).resolve())] = sha(Path(__file__))
    policy_path = Path(__file__).with_name("provenance-policy.json")
    original_hashes[str(policy_path)] = sha(policy_path)
    for path in sorted(policy_path.parent.joinpath("historical-documents").rglob("*.md")):
        original_hashes[str(path)] = sha(path)
    analysis, values, groups, acceptance, checks = validate(source, root)
    for name in required:
        shutil.copyfile(source / name, out / name)
    shutil.copyfile(root / "data" / "synthetic_prices.csv", out / "fixture.csv")
    script_dest = out / "convergence_figures.py"
    if Path(__file__).resolve() != script_dest:
        shutil.copyfile(Path(__file__), script_dest)
    shutil.copyfile(policy_path, out / "provenance-policy.json")
    shutil.copytree(policy_path.parent / "historical-documents", out / "historical-documents")
    plotted = {"curves": [], "seed_series": [], "acceptance": [],
               "scales": {"N": "log", "positive_metrics": "log; exact zeros marked separately",
                          "signed_error": "symlog", "linear_threshold": 0.001}}

    def configure_x(ax):
        ax.set_xscale("log")
        ax.set_xticks(NS)
        ax.set_xticklabels(("10K", "100K", "1M", "10M"))
        ax.xaxis.set_minor_formatter(NullFormatter())
        ax.grid(True, which="major", color="#d9dfe5", linewidth=0.7)
        ax.set_xlabel("Scenarios, N (log scale)")
        ax.set_xlim(NS[0] / 1.25, NS[-1] * 1.25)

    def positive_plot(ax, xs, ys, **kwargs):
        displayed, zero_x = positive_log_points(xs, ys)
        ax.plot(xs, displayed, **kwargs)
        if zero_x:
            ax.plot(zero_x, [-0.08] * len(zero_x), transform=ax.get_xaxis_transform(),
                    clip_on=False, linestyle="none", marker="v", color=kwargs.get("color"), markersize=7)
            ax.text(1, -0.13, "v = exact zero (outside log axis)", transform=ax.transAxes,
                    ha="right", fontsize=8)

    def engine_curve(ax, field, alpha):
        for i, engine in enumerate(ENGINES):
            ys = [float(groups[(engine, n, alpha)][field]) for n in NS]
            plotted["curves"].append({"engine": engine, "alpha": alpha, "metric": field,
                                       "N": list(NS), "values": ys})
            positive_plot(ax, NS, ys, color=COLORS[i], marker=MARKERS[i],
                          linestyle=STYLES[i], linewidth=1.7, markersize=7 if i == 3 else 5,
                          markerfacecolor="none" if i == 3 else COLORS[i], label=LABELS[engine])
        ax.set_yscale("log")
        configure_x(ax)

    outputs = []
    combined = PdfPages(out / "convergence_figures.pdf")

    def save(fig, stem):
        combined.savefig(fig, bbox_inches="tight")
        for ext in ("png", "svg", "pdf"):
            path = out / f"{stem}.{ext}"
            fig.savefig(path, dpi=200, bbox_inches="tight")
            outputs.append(path.name)
        plt.close(fig)

    fig, axes = plt.subplots(2, 2, figsize=(12.6, 8.6), sharey="row")
    fig.subplots_adjust(left=0.10, right=0.98, top=0.88, bottom=0.22, hspace=0.43, wspace=0.23)
    fig.suptitle("Analytical error versus scenario count", fontsize=17, fontweight="bold")
    for col, alpha in enumerate(ALPHAS):
        for row, field in enumerate(("absolute_error_of_mean", "descriptive_mae")):
            ax = axes[row, col]
            engine_curve(ax, field, alpha)
            ax.set_title(f"{alpha:.0%} VaR")
            ax.set_ylabel("Absolute error of five-seed mean\n(value units, log scale)" if row == 0
                          else "Mean absolute error across seeds\n(value units, log scale)")
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", bbox_to_anchor=(0.5, 0.075), ncol=4, frameon=False)
    fig.text(0.5, 0.025, "One synthetic fixture; five fixed seeds. Descriptive errors do not replace 10M acceptance.\n"
             "Full-device and hybrid values overlap exactly in this dataset; no equivalence guarantee is implied.",
             fontsize=9, ha="center", va="bottom")
    save(fig, "01_error_vs_scenarios")

    fig, axes = plt.subplots(2, 4, figsize=(15.8, 8.3))
    fig.subplots_adjust(left=0.065, right=0.985, top=0.88, bottom=0.20, hspace=0.34, wspace=0.12)
    fig.suptitle("Seed-to-seed signed analytical errors", fontsize=17, fontweight="bold")
    for row, alpha in enumerate(ALPHAS):
        largest = max(abs(float(r["signed_error"])) for k, r in values.items() if k[3] == alpha)
        for col, engine in enumerate(ENGINES):
            ax = axes[row, col]
            for i, seed in enumerate(SEEDS):
                ys = [float(values[(engine, n, seed, alpha)]["signed_error"]) for n in NS]
                plotted["seed_series"].append({"engine": engine, "alpha": alpha, "seed": seed,
                                               "N": list(NS), "values": ys})
                ax.plot(NS, ys, color=SEED_COLORS[i], label=f"Seed {seed}", linewidth=1.1,
                        linestyle=("-", "--", "-.", ":", "-")[i], marker="o", markersize=3)
            ax.axhline(0, color="#222222", linewidth=0.85)
            ax.axhspan(-0.001, 0.001, color="#eef1f5", zorder=0)
            ax.set_yscale("symlog", linthresh=0.001, linscale=0.75)
            ax.set_ylim(-largest * 1.25, largest * 1.25)
            ax.set_title(f"{LABELS[engine]} | {alpha:.0%} VaR")
            configure_x(ax)
            if col == 0:
                ax.set_ylabel("Signed error (value units)\nsymmetric log scale")
            else:
                ax.tick_params(axis="y", labelleft=False)
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", bbox_to_anchor=(0.5, 0.065), ncol=5, frameon=False)
    fig.text(0.5, 0.015, "Gray band: linear y-axis region |error| <= 0.001; raw signs and zeros are preserved.\n"
             "Lines identify fixed seeds across N; same seed labels are not common inputs across engines.",
             fontsize=9, ha="center", va="bottom")
    save(fig, "02_seed_signed_errors")

    fig, axes = plt.subplots(1, 2, figsize=(12.6, 5.0), sharey=True)
    fig.subplots_adjust(left=0.10, right=0.98, top=0.83, bottom=0.30, wspace=0.23)
    fig.suptitle("Variation across the five seeds", fontsize=17, fontweight="bold")
    for ax, alpha in zip(axes, ALPHAS):
        engine_curve(ax, "sample_stddev", alpha)
        ax.set_title(f"{alpha:.0%} VaR")
        ax.set_ylabel("Sample standard deviation of VaR\n(value units, n-1 denominator; log scale)")
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", bbox_to_anchor=(0.5, 0.105), ncol=4, frameon=False)
    fig.text(0.5, 0.025, "Sample spread is not a confidence interval or universal error guarantee.\n"
             "Overlapping GPU curves retain their original values.", fontsize=9, ha="center", va="bottom")
    save(fig, "03_seed_standard_deviation")

    fig, axes = plt.subplots(1, 2, figsize=(12.6, 5.0), sharey=True)
    fig.subplots_adjust(left=0.17, right=0.98, top=0.83, bottom=0.27, wspace=0.30)
    fig.suptitle("Separate analytical acceptance at N = 10,000,000", fontsize=16, fontweight="bold")
    for ax, alpha in zip(axes, ALPHAS):
        for i, engine in enumerate(ENGINES):
            r = acceptance[(engine, alpha)]
            ratio = float(r["absolute_error_of_mean"]) / float(r["allowed_error"])
            plotted["acceptance"].append({"engine": engine, "alpha": alpha, "ratio": ratio,
                                          "absolute_error_of_mean": float(r["absolute_error_of_mean"]),
                                          "allowed_error": float(r["allowed_error"])})
            if ratio > 0:
                ax.plot(ratio, 3 - i, marker=MARKERS[i], color=COLORS[i], markersize=7,
                        markerfacecolor="none" if i == 3 else COLORS[i])
                ax.annotate(f"{ratio:.5f}", (ratio, 3 - i), xytext=(8, 0),
                            textcoords="offset points", va="center", fontsize=9)
            else:
                ax.plot(-0.03, 3 - i, transform=ax.get_yaxis_transform(), marker="<", clip_on=False)
                ax.annotate("exact zero", (0, 3 - i), xycoords=ax.get_yaxis_transform(), fontsize=9)
        ax.set_xscale("log")
        ax.axvline(1, color="#444444", linestyle="--", linewidth=1.2)
        ax.set_xlim(0.001, 2.0)
        ax.set_ylim(-0.6, 3.6)
        ax.set_yticks((3, 2, 1, 0), [LABELS[e] for e in ENGINES])
        ax.set_title(f"{alpha:.0%} VaR | all four rows pass")
        ax.set_xlabel("Absolute error of mean / allowed error (log scale)")
        ax.grid(True, axis="x", which="major", color="#d9dfe5", linewidth=0.7)
        ax.text(1, 3.42, "Limit = 1", ha="right", color="#444444", fontsize=9)
    fig.text(0.5, 0.025, "Acceptance: |mean(VaR) - reference| <= 0.01 max(|reference|, 0.01 V0).\n"
             "These eight rows reuse existing 10M observations; individual errors, MAE and RMSE are not the criterion.",
             fontsize=9, ha="center", va="bottom")
    save(fig, "04_separate_10m_acceptance")
    combined.close()
    outputs.append("convergence_figures.pdf")
    (out / "plotted-data.json").write_text(json.dumps(plotted, indent=2) + "\n", encoding="ascii")

    for path, original in original_hashes.items():
        check_equal(sha(Path(path)), original, "unchanged input evidence")
    checks["original_evidence_unchanged"] = True
    checks["new_simulation_processes"] = 0
    checks["zero_display_policy"] = "Exact zeros remain raw zeros; separate labeled markers outside positive log axes; signed errors use symlog with linear +/-0.001 region"
    checks["figures"] = outputs
    (out / "verification.json").write_text(json.dumps(checks, indent=2) + "\n", encoding="utf-8")
    readme = """# Offline convergence figures

Four figure families are provided as PNG (200 dpi), SVG (editable vector text),
and PDF (vector), plus a four-page combined convergence_figures.pdf.
Inputs are exact copies of the completed fixed-fixture
convergence evidence. No simulation, timing, profiling or optimization ran.

1. 01_error_vs_scenarios: absolute error of five-seed mean and descriptive MAE.
2. 02_seed_signed_errors: all 160 per-seed errors, separate engine/alpha panels.
3. 03_seed_standard_deviation: sample variation across five seeds, denominator n-1.
4. 04_separate_10m_acceptance: error-of-mean divided by the unchanged allowed error.

All inputs and their provenance remain retained. verification.json independently
checks coverage, fixture calibration/references, all statistics and acceptance.
The copied delivery-manifest.json retains its ORIGINAL source paths and is not
a hash inventory for this figure package; use figure-manifest.json for this package.

Relative error is N/A when |reference| < 0.01 V0, with error/V0 retained; plotted
errors here are in portfolio value units. Positive log axes omit zero from the
log transform and mark it separately without replacing raw values. Signed-error
panels use a symmetric log scale with the labeled linear region. No fitted rate,
monotonicity requirement, confidence interval, market validity or general guarantee
is claimed. Five seeds and one synthetic fixture are limited evidence.

Full-device/hybrid native observations happen to match in this dataset. Their
curves are distinguished by solid filled versus dashed hollow markers; no point
is jittered or changed. Equal seed labels do not imply common inputs, independent
engine comparisons or batch-size invariance. Historical serial source-to-binary
verification=false, missing published standalone OpenMP cache, and mixed-revision
reuse limits from the original evidence remain unchanged. No speedup claim is
recalculated using convergence data.

Reproduce with the existing Python/Matplotlib environment (no installation):
  python -B convergence_figures.py --repository <current-repository-root> --output <new-results-directory>
An existing output directory is rejected. The complete original hash-bound input
archive must still be present under evidence/v030-convergence-windows-20261020.

This package is local/ignored; no commit or push is performed by this script.
"""
    (out / "README.md").write_text(readme, encoding="ascii")
    manifest = {
        "schema_version": 2,
        "parent_manifest_sha256": checks["provenance"]["parent_manifest_sha256"],
        "purpose": "Offline figures only, from existing verified synthetic convergence evidence",
        "source_directory": str(source), "engine_tested_source": "b5f1a0f5b72bca8f1f21555236d938501f7faee8",
        "python": sys.version, "matplotlib": matplotlib.__version__,
        "input_sha256": original_hashes, "fixture_sha256": sha(out / "fixture.csv"),
        "new_simulation_processes": 0,
        "outputs": [{"file": p.relative_to(out).as_posix(), "sha256": sha(p)}
                    for p in sorted(out.rglob("*")) if p.is_file()
                    and "matplotlib-config" not in p.parts],
    }
    (out / "figure-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": "passed", "output": str(out), "figures": outputs,
                      "groups": 32, "values": 160, "acceptance_rows": 8}))


if __name__ == "__main__":
    main()
