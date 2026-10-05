import unittest

from experiment_annotations import paired_summary, transform


class AnnotationExperimentTests(unittest.TestCase):
    def test_bootstrap_requires_clear_gain_and_rejects_regression(self):
        self.assertTrue(paired_summary([.8] * 10)["target_gain"])
        self.assertFalse(paired_summary([.99] * 10)["target_gain"])
        self.assertTrue(paired_summary([1.1] * 10)["significant_regression"])
        self.assertFalse(paired_summary([.8, 1.2] * 5)["target_gain"])
        for invalid in [[], [float("nan")], [float("inf")], [0], [-1]]:
            with self.assertRaises(ValueError):
                paired_summary(invalid)

    def test_baseline_is_byte_identical_and_tracing_is_not_annotated(self):
        text = "#if !Tracing\n @inlinable\n#endif\npublic func decide(_ x: Int) -> Int? { nil }"
        self.assertEqual(transform(text, "baseline"), text)
        updated = transform(text, "inline")
        self.assertIn("@inlinable @inline(__always)\n#endif", updated)

    def test_freezing_is_explicit_and_does_not_change_unlisted_types(self):
        text = "public struct BinaryFirstMatch<A, B> {}\npublic struct FutureLayout {}"
        updated = transform(text, "inline_frozen")
        self.assertIn("@frozen\npublic struct BinaryFirstMatch", updated)
        self.assertNotIn("@frozen\npublic struct FutureLayout", updated)


if __name__ == "__main__":
    unittest.main()
