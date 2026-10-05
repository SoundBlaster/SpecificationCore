import copy
from pathlib import Path
import unittest

from experiment_annotations import FILES, paired_summary, performance_qualified, transform


def active_source(text, tracing, aggressive_inlining=False):
    """Evaluate the simple Tracing conditionals used by attribute fixtures."""
    stack = [True]
    lines = []
    for line in text.splitlines():
        directive = line.strip()
        if directive in ("#if Tracing", "#if !Tracing", "#if AggressiveInlining && !Tracing"):
            condition = {
                "#if Tracing": tracing,
                "#if !Tracing": not tracing,
                "#if AggressiveInlining && !Tracing": aggressive_inlining and not tracing,
            }[directive]
            stack.append(stack[-1] and condition)
        elif directive == "#else":
            stack[-1] = stack[-2] and not stack[-1]
        elif directive == "#endif":
            stack.pop()
        elif stack[-1]:
            lines.append(line)
    assert len(stack) == 1
    return "\n".join(lines)


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
        self.assertIn("@inline(__always)", active_source(updated, tracing=False))
        self.assertNotIn("@inline(__always)", active_source(updated, tracing=True))

    def test_unconditional_inlinable_preserves_tracing_attribute_surface(self):
        text = "@inlinable\npublic func isSatisfiedBy(_ x: Int) -> Bool { true }"
        for variant in ["inline", "inline_frozen"]:
            updated = transform(text, variant)
            self.assertEqual(active_source(updated, tracing=True), text)
            self.assertIn("@inline(__always)", active_source(updated, tracing=False))

    def test_production_attribute_insertion_is_always_tracing_guarded(self):
        root = Path(__file__).resolve().parents[1] / "Sources/SpecificationCore"
        for name in FILES:
            updated = transform((root / name).read_text(), "inline")
            lines = updated.splitlines()
            attributes = [i for i, line in enumerate(lines) if "@inline(__always)" in line]
            self.assertTrue(attributes, name)
            for index in attributes:
                self.assertIn(lines[index - 1].strip(),
                              ["#if !Tracing", "#if AggressiveInlining && !Tracing"], name)
                self.assertEqual(lines[index + 1].strip(), "#endif", name)

    def test_target_gain_does_not_require_balanced_speedup(self):
        cells = {"static": {"status": "MEASURED", "cost_gate": True, "strategies": {
            "nested_growing_leaves_chain": {"target_gain": True, "significant_regression": False},
            "static_balanced": {"target_gain": False, "significant_regression": False}}}}
        self.assertTrue(performance_qualified(cells))
        regression = copy.deepcopy(cells)
        regression["static"]["strategies"]["static_balanced"]["significant_regression"] = True
        self.assertFalse(performance_qualified(regression))
        no_gain = copy.deepcopy(cells)
        no_gain["static"]["strategies"]["nested_growing_leaves_chain"]["target_gain"] = False
        self.assertFalse(performance_qualified(no_gain))
        costly = copy.deepcopy(cells)
        costly["static"]["cost_gate"] = False
        self.assertFalse(performance_qualified(costly))
        cells["policy"] = {"status": "BUILD_FAILED_OR_UNAVAILABLE"}
        self.assertFalse(performance_qualified(cells))

    def test_shipped_forced_inlining_requires_trait_and_excludes_tracing(self):
        root = Path(__file__).resolve().parents[1] / "Sources/SpecificationCore"
        for name in FILES:
            text = (root / name).read_text()
            for tracing in (False, True):
                for enabled in (False, True):
                    active = active_source(text, tracing, enabled)
                    self.assertEqual("@inline(__always)" in active, enabled and not tracing,
                                     (name, tracing, enabled))

    def test_freezing_is_explicit_and_does_not_change_unlisted_types(self):
        text = "public struct BinaryFirstMatch<A, B> {}\npublic struct FutureLayout {}"
        updated = transform(text, "inline_frozen")
        self.assertIn("@frozen\npublic struct BinaryFirstMatch", updated)
        self.assertNotIn("@frozen\npublic struct FutureLayout", updated)


if __name__ == "__main__":
    unittest.main()
