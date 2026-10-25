"""Render exported portfolio results only. No simulation or benchmark is run."""
import json
from pathlib import Path
import sys

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import portfolio_campaign as campaign


def main():
    p = campaign.frozen()
    conv = campaign.read_rows("convergence.csv")
    bench = campaign.read_rows("benchmark-summary.csv")
    ref = campaign.load(campaign.PUBLIC/"reference.json")
    destination = campaign.PUBLIC/"figures"
    destination.mkdir(exist_ok=True)
    plt.rcParams.update({"font.size":10, "svg.hashsalt":"portfolio-v1", "axes.unicode_minus":False, "axes.grid":True, "grid.alpha":.25})
    plotted = dict(convergence=[], runtime=[], speedup=[])
    names = list(p["fixtures"])
    fig, axes = plt.subplots(3, 2, figsize=(12, 10), sharex=True)
    for row, name in enumerate(names):
        v0 = ref["cases"][name]["initial_value"]
        for column, alpha in enumerate((.95, .99)):
            ax = axes[row, column]
            for config in p["validation_engines"]:
                rows = [r for r in conv if r["fixture"] == name and float(r["confidence"]) == alpha and r["config"] == config]
                x = [int(r["scenarios"]) for r in rows]
                y = [float(r["signed_error"])*10000/v0 for r in rows]
                sd = [float(r["sample_sd"])*10000/v0 for r in rows]
                artist = ax.errorbar(x, y, yerr=sd, marker="o", capsize=3, label=config)
                assert np.array_equal(np.asarray(artist.lines[0].get_ydata(), dtype=float), y)
                plotted["convergence"].append(dict(fixture=name, confidence=alpha, config=config, n=x, signed_error_bp=y, sample_sd_bp=sd))
            q = next(q for q in ref["cases"][name]["quantiles"] if q["confidence"] == alpha)
            ax.axhspan((q["lower"]-q["var"])*10000/v0, (q["upper"]-q["var"])*10000/v0, color="grey", alpha=.2)
            ax.axhline(5, color="black", linestyle=":"); ax.axhline(-5, color="black", linestyle=":")
            ax.axhline(0, color="black", linewidth=.6)
            ax.set(xscale="log", title=f"{name}, alpha={alpha:.2f}", ylabel="Signed error / V0 (basis points)")
    axes[0, 0].legend(ncol=3, fontsize=9)
    for ax in axes[-1]: ax.set_xlabel("Scenarios N")
    fig.suptitle("Portfolio convergence: realized five-seed mean relative to independent 20M reference", fontsize=12)
    fig.text(.5, .015, "Bars: per-seed sample SD (not CI); grey: reference quantile uncertainty; dotted: +/-5 bp practical target.", ha="center", fontsize=9)
    fig.tight_layout(rect=(0,.035,1,.96)); export(fig, destination/"convergence")

    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    for ax, name in zip(axes, p["benchmark"]["fixtures"]):
        for config in p["benchmark"]["configurations"]:
            rows = [r for r in bench if r["fixture"] == name and r["config"] == config]
            x = [int(r["scenarios"]) for r in rows]
            y = [float(r["mean_ms"]) for r in rows]
            sd = [float(r["sample_sd_ms"]) for r in rows]
            artist = ax.errorbar(x, y, yerr=sd, marker="o", capsize=3, label=config)
            assert np.array_equal(np.asarray(artist.lines[0].get_ydata(), dtype=float), y)
            plotted["runtime"].append(dict(fixture=name, config=config, n=x, mean_ms=y, sample_sd_ms=sd))
        ax.set(xscale="log", yscale="log", title=name, xlabel="Scenarios N", ylabel="Primary engine wall time (ms)")
    handles, labels = axes[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", ncol=7, fontsize=9)
    fig.suptitle("Native portfolio timing: fresh processes/contexts; mean +/- sample SD, 10 measured runs")
    fig.tight_layout(rect=(0,.08,1,.92)); export(fig, destination/"runtime")

    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    for ax, name in zip(axes, p["benchmark"]["fixtures"]):
        for baseline, label in [("serial", "Serial / CUDA"), ("best_openmp", "Best OpenMP / CUDA")]:
            x, ratios, lower, upper = [], [], [], []
            for n in p["scenario_grid"]:
                rows = [r for r in bench if r["fixture"] == name and int(r["scenarios"]) == n]
                cuda = next(r for r in rows if r["config"] == "cuda")
                config = "serial" if baseline == "serial" else cuda["best_openmp"]
                base = next(r for r in rows if r["config"] == config)
                a, b, sa, sb = (float(base["mean_ms"]), float(cuda["mean_ms"]), float(base["sample_sd_ms"]), float(cuda["sample_sd_ms"]))
                ratio = a/b
                lo, hi = max(0., a-sa)/(b+sb), (a+sa)/max(b-sb, b*.001)
                x.append(n); ratios.append(ratio); lower.append(ratio-lo); upper.append(hi-ratio)
            ax.errorbar(x, ratios, yerr=[lower, upper], marker="o", capsize=3, label=label)
            plotted["speedup"].append(dict(fixture=name, baseline=baseline, n=x, ratio=ratios, lower_error=lower, upper_error=upper))
        ax.axhline(1, color="black", linestyle="--", linewidth=.8)
        ax.set(xscale="log", title=name, xlabel="Scenarios N", ylabel="Speedup (ratio of mean wall times)")
        ax.legend(fontsize=9)
    fig.suptitle("CUDA portfolio speedup; below 1 means the CPU baseline is faster")
    fig.text(.5, .015, "Whiskers: ratios of mean +/- sample SD endpoints, descriptive envelope, not confidence intervals.", ha="center", fontsize=9)
    fig.tight_layout(rect=(0,.04,1,.92)); export(fig, destination/"speedup")
    campaign.save(campaign.PUBLIC/"figure-data.json", plotted)
    print("Rendered 3 PNG/SVG pairs and exported checked artist data")


def export(fig, stem):
    fig.savefig(stem.with_suffix(".png"), dpi=150, metadata={"Software":"portfolio campaign matplotlib"})
    fig.savefig(stem.with_suffix(".svg"), metadata={"Date":None})
    plt.close(fig)


if __name__ == "__main__":
    main()
