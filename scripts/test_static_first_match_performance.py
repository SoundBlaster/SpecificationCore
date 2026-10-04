import unittest

from check_static_first_match_performance import compare, parse_sample, summarize


def csv_sample():
    strategies = ["nested_growing_leaves_chain", "static_balanced"]
    return "round,strategy,elapsed_ns,ns_per_candidate,checksum\n" + "".join(
        f"{i},{strategy},120000,1.0,42\n" for i in range(32) for strategy in strategies)


class StaticFirstMatchPerformanceTests(unittest.TestCase):
    def test_parses_complete_alternating_benchmark(self):
        result = parse_sample(csv_sample())
        self.assertEqual(result["static_balanced"], {"median": 1.0, "checksum": 42})

    def test_rejects_missing_strategy_round_and_unstable_checksum(self):
        bad_samples = [
            csv_sample().replace("31,static_balanced,120000,1.0,42\n", ""),
            csv_sample().replace("31,static_balanced,120000,1.0,42\n", "31,unknown,120000,1.0,42\n"),
            csv_sample().replace("31,static_balanced,120000,1.0,42", "31,static_balanced,120000,1.0,43"),
        ]
        for sample in bad_samples:
            with self.subTest(sample=sample[-50:]), self.assertRaises(ValueError):
                parse_sample(sample)

    def test_rejects_invalid_timing_and_duplicate_samples(self):
        bad_samples = [
            csv_sample().replace("120000", "0", 1),
            csv_sample().replace("1.0", "nan", 1),
            csv_sample() + "0,nested_growing_leaves_chain,120000,1.0,42\n",
        ]
        for sample in bad_samples:
            with self.subTest(sample=sample[-60:]), self.assertRaises(ValueError):
                parse_sample(sample)

    def test_rejects_stable_but_different_strategy_checksums(self):
        sample = csv_sample().replace("static_balanced,120000,1.0,42", "static_balanced,120000,1.0,43")
        with self.assertRaisesRegex(ValueError, "different semantic checksums"):
            parse_sample(sample)

    def test_gate_tolerates_small_noise_and_rejects_large_regression(self):
        baseline = summarize([20, 21, 20, 22, 20])
        self.assertFalse(compare(baseline, summarize([24, 22, 23, 22, 24]))["regression"])
        self.assertTrue(compare(baseline, summarize([80] * 5))["regression"])


if __name__ == "__main__":
    unittest.main()
