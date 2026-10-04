import unittest

from compare_policy_performance import compare, parse_sample, summarize


def csv_sample():
    return "round,strategy,elapsed_ns,ns_per_candidate,checksum\n" + "".join(
        f"{i},{strategy},120000,1.0,42\n" for i in range(5) for strategy in ["first_match", "predicate"])


class PerformanceReportTests(unittest.TestCase):
    def test_complete_samples(self):
        self.assertEqual(parse_sample(csv_sample())["first_match"], {"median": 1.0, "checksum": 42})

    def test_rejects_missing_round(self):
        with self.assertRaises(ValueError):
            parse_sample(csv_sample().replace("4,predicate,120000,1.0,42\n", ""))

    def test_rejects_duplicate(self):
        with self.assertRaises(ValueError):
            parse_sample(csv_sample() + "0,predicate,120000,1.0,42\n")

    def test_rejects_bad_timing_and_checksum(self):
        for bad in [csv_sample().replace("120000", "0"), csv_sample().replace("1.0", "nan"),
                    csv_sample().replace("4,predicate,120000,1.0,42", "4,predicate,120000,1.0,99")]:
            with self.assertRaises(ValueError):
                parse_sample(bad)

    def test_gate_detects_large_regression(self):
        baseline = summarize([20] * 5)
        self.assertFalse(compare(baseline, summarize([21] * 5))["regression"])
        self.assertTrue(compare(baseline, summarize([60] * 5))["regression"])


if __name__ == "__main__":
    unittest.main()
