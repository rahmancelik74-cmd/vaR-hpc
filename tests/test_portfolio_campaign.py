"""Small tooling checks only; never launch a campaign during test discovery."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("portfolio_campaign", ROOT/"scripts/portfolio_campaign.py")
campaign = importlib.util.module_from_spec(spec)
spec.loader.exec_module(campaign)


class PortfolioCampaignTests(unittest.TestCase):
    def test_practical_is_worst_case_not_interval_overlap(self):
        self.assertEqual(campaign.practical(10, 9.9, 10.1, .5)[0], "pass")
        self.assertEqual(campaign.practical(11, 9.9, 10.1, .5)[0], "fail")
        self.assertEqual(campaign.practical(10.4, 9.9, 10.1, .5)[0], "pass")
        self.assertEqual(campaign.practical(10.45, 9.9, 10.1, .5)[0], "inconclusive")
        self.assertEqual(campaign.practical(10, 9, 11, .5)[0], "inconclusive")

    def test_frozen_matrix_and_workloads(self):
        p = campaign.frozen()
        self.assertEqual(len(p["fixtures"])*len(p["scenario_grid"])*3*5*2, 270)
        self.assertEqual(2*3*7*13, p["benchmark"]["expected_processes"])
        self.assertEqual(sum(p["family_error"][k] for k in ("reference_quantile_intervals", "reference_uniform_cdf_DKW", "native_order_statistics")), .01)
        self.assertEqual(campaign.fixture(ROOT/p["fixtures"]["two-positive"]["path"])["initial"], 440)
        self.assertEqual(campaign.fixture(ROOT/p["fixtures"]["five-identity"]["path"])["initial"], 710)

    def test_reference_quantile_coverage(self):
        try:
            import scipy.stats
        except ImportError:
            self.skipTest("SciPy not installed; application/standard-library checks remain available")
        lo, hi, coverage = campaign.order_interval(100, .95, .05)
        self.assertLess(lo, hi)
        self.assertGreaterEqual(coverage, .95-1e-12)
        for alpha in (.95, .99):
            self.assertGreaterEqual(campaign.order_interval(20000000, alpha, .0025/6)[2], 1-.0025/6-1e-12)


if __name__ == "__main__":
    unittest.main()
