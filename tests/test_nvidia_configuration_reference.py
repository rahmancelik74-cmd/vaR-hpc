"""Supplementary device-reported bandwidth math, units and evidence boundary."""
import copy
from decimal import Decimal, localcontext
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import unittest

BASE = Path(__file__).resolve().parents[1] / "evidence/v030-nvidia-configuration-reference-20261021"
SPEC = importlib.util.spec_from_file_location("configuration_reference", BASE / "calculate.py")
REFERENCE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REFERENCE)


class NvidiaConfigurationReferenceTests(unittest.TestCase):
    def setUp(self):
        self.report = json.loads((BASE / "report-extract.json").read_text(encoding="ascii"))
        self.totals = {
            "full-device": dict(kernels=14, read_bytes=834700672, write_bytes=700582528, duration_ns=16407904),
            "hybrid": dict(kernels=307, read_bytes=258276736, write_bytes=0, duration_ns=10498528)}

    def test_saved_result_matches_hash_bound_archived_inputs(self):
        actual = REFERENCE.verify_saved_calculation()
        self.assertFalse(actual["published_specification_gap_closed"])
        self.assertFalse(actual["sustainable_peak_or_whole_application_utilisation_claimed"])

    def test_percentages_match_independent_exact_rational_arithmetic(self):
        actual = REFERENCE.calculate(self.report, self.totals)
        for mode, total in self.totals.items():
            rational = Fraction((total["read_bytes"] + total["write_bytes"]) * 100000,
                                total["duration_ns"] * 256032)
            with localcontext() as context:
                context.prec = 60
                expected = Decimal(rational.numerator) / Decimal(rational.denominator)
                result = Decimal(actual["results"][mode]["percentage_of_nvidia_app_reported_configuration_bandwidth"])
                self.assertLess(abs(result - expected), Decimal("1e-47"))
        self.assertEqual(actual["bandwidth_from_displayed_rate_GBps"], "256.00")
        self.assertFalse(actual["extra_DDR_factor_used"])

    def test_display_rounding_is_compatible_but_hidden_rate_is_not_asserted(self):
        actual = REFERENCE.calculate(self.report, self.totals)
        self.assertEqual(actual["rate_implied_by_bandwidth_Gbps"], "16.002")
        self.assertTrue(actual["implied_rate_is_not_an_independently_reported_exact_rate"])
        changed = copy.deepcopy(self.report)
        changed["fields"]["memory_bandwidth"]["value"] = "320.000 GB/saniye"
        with self.assertRaisesRegex(ValueError, "incompatible"):
            REFERENCE.calculate(changed, self.totals)

    def test_clock_or_binary_bandwidth_units_are_not_silently_converted(self):
        for field, value in [("memory_data_rate", "8001 MHz"), ("memory_data_rate", "16.00 GB/s"),
                             ("memory_bandwidth", "256032 MiB/s")]:
            with self.subTest(field=field, value=value):
                changed = copy.deepcopy(self.report)
                changed["fields"][field]["value"] = value
                with self.assertRaises(ValueError):
                    REFERENCE.calculate(changed, self.totals)

    def test_invalid_values_and_nonpositive_duration_fail(self):
        for field, value in [("memory_data_rate", "NaN Gbps"), ("memory_data_rate", "0.00 Gbps"),
                             ("memory_bandwidth", "0.000 GB/saniye"), ("memory_interface", "0-bit")]:
            changed = copy.deepcopy(self.report)
            changed["fields"][field]["value"] = value
            with self.assertRaises(ValueError):
                REFERENCE.calculate(changed, self.totals)
        changed_totals = copy.deepcopy(self.totals)
        changed_totals["hybrid"]["duration_ns"] = 0
        with self.assertRaisesRegex(ValueError, "Duration"):
            REFERENCE.calculate(self.report, changed_totals)

    def test_device_report_cannot_be_promoted_to_published_specification(self):
        for key, value in [("evidence_class", "A"), ("published_specification_established", True)]:
            changed = copy.deepcopy(self.report)
            changed[key] = value
            with self.assertRaisesRegex(ValueError, "class-B"):
                REFERENCE.calculate(changed, self.totals)

    def test_another_gpu_report_is_not_applied_to_this_workload(self):
        changed = copy.deepcopy(self.report)
        changed["fields"]["gpu"]["value"] = "NVIDIA GeForce RTX 4060"
        with self.assertRaisesRegex(ValueError, "Reference GPU"):
            REFERENCE.calculate(changed, self.totals)


if __name__ == "__main__":
    unittest.main()
