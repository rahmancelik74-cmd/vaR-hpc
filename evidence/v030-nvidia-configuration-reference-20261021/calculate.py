"""Read-only supplementary NVIDIA configuration-reference calculation."""
import argparse
from decimal import Decimal, localcontext
import hashlib
import importlib.util
import json
from pathlib import Path
import re

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]


def positive_value(text, unit):
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?) " + re.escape(unit), text)
    if not match or Decimal(match[1]) <= 0:
        raise ValueError("Expected a positive explicit " + unit + " value")
    return Decimal(match[1])


def calculate(report, totals):
    if report["evidence_class"] != "B" or report["published_specification_established"] is not False:
        raise ValueError("This calculation requires a separately labelled class-B reference")
    fields = report["fields"]
    if fields["gpu"]["value"] != "NVIDIA GeForce RTX 4060 Laptop GPU":
        raise ValueError("Reference GPU does not match this archived workload")
    rate = positive_value(fields["memory_data_rate"]["value"], "Gbps")
    width_match = re.fullmatch(r"([1-9][0-9]*)-bit", fields["memory_interface"]["value"])
    if not width_match:
        raise ValueError("Expected positive integral interface width in bits")
    width = Decimal(width_match[1])
    reference = positive_value(fields["memory_bandwidth"]["value"], "GB/saniye")
    with localcontext() as context:
        context.prec = 50
        display_derived = rate * width / 8
        implied_rate = reference * 8 / width
        rate_resolution = Decimal(1).scaleb(rate.as_tuple().exponent)
        compatible = abs(implied_rate - rate) < rate_resolution / 2
        if not compatible:
            raise ValueError("Reported bandwidth is incompatible with displayed rate/width rounding")
        results = {}
        for mode in ("full-device", "hybrid"):
            total = totals[mode]
            for key in ("read_bytes", "write_bytes", "duration_ns"):
                if type(total[key]) is not int or total[key] < 0:
                    raise ValueError("Expected nonnegative integral counter totals")
            if total["duration_ns"] == 0:
                raise ValueError("Duration must be positive")
            byte_count = total["read_bytes"] + total["write_bytes"]
            # Byte/ns equals decimal GB/s. No displayed GB/s input is used.
            measured = Decimal(byte_count) / Decimal(total["duration_ns"])
            percent = Decimal(byte_count) * 100 / (Decimal(total["duration_ns"]) * reference)
            results[mode] = dict(kernels=total["kernels"], read_bytes=total["read_bytes"],
                                 write_bytes=total["write_bytes"], duration_ns=total["duration_ns"],
                                 measured_GBps=str(measured),
                                 percentage_of_nvidia_app_reported_configuration_bandwidth=str(percent))
        return dict(
            reference_label="NVIDIA App System Information-reported configuration bandwidth",
            reference_GBps=str(reference), effective_rate_display_Gbps=str(rate),
            interface_bits=int(width), bandwidth_from_displayed_rate_GBps=str(display_derived),
            reported_minus_display_derived_GBps=str(reference - display_derived),
            rate_implied_by_bandwidth_Gbps=str(implied_rate),
            implied_rate_is_not_an_independently_reported_exact_rate=True,
            difference_compatible_with_displayed_rate_rounding=compatible,
            extra_DDR_factor_used=False, published_specification_gap_closed=False,
            scope="Cold-cache collected-kernel byte/duration ratio; transfers and host costs excluded",
            sustainable_peak_or_whole_application_utilisation_claimed=False,
            results=results)


def load_inputs():
    manifest = json.loads((BASE / "manifest.json").read_text(encoding="ascii"))
    for entries, directory, key in ((manifest["selected_files"], BASE, "file"),
                                    (manifest["immutable_parents"], ROOT, "path")):
        for entry in entries:
            path = (directory / entry[key]).resolve()
            if directory.resolve() not in path.parents:
                raise ValueError("Evidence path escapes its root")
            if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
                raise ValueError("Changed evidence: " + entry[key])
    baseline = ROOT / "evidence/v030-dram-baseline-20261020"
    spec = importlib.util.spec_from_file_location("original_dram_verifier", baseline / "verify.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    kernels = json.loads((baseline / "kernel-metrics.json").read_text(encoding="ascii"))
    totals = {mode: helper.summarize(kernels[mode], mode)["all-collected-kernels"]
              for mode in ("full-device", "hybrid")}
    return json.loads((BASE / "report-extract.json").read_text(encoding="ascii")), totals


def verify_saved_calculation():
    report, totals = load_inputs()
    result = calculate(report, totals)
    if result != json.loads((BASE / "calculation.json").read_text(encoding="ascii")):
        raise ValueError("Saved supplementary calculation differs from original inputs")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = verify_saved_calculation() if args.check else calculate(*load_inputs())
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
