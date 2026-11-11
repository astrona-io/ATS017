"""Exercise intentional failure and execution-error handling without a cluster."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('start_state', Path(__file__).with_name('start-state.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class VerdictTests(unittest.TestCase):
    def test_intentional_failure(self):
        self.assertFalse(module.verdict(1, 'FAIL: wrong replica count\n'))

    def test_preserved_constraint(self):
        self.assertTrue(module.verdict(0, 'PASS: namespace still exists\n'))

    def test_execution_errors_are_not_rejections(self):
        for code, output in [(127, 'command not found\nFAIL: no result'),
                             (1, 'Traceback (most recent call last)\nFAIL: no result'),
                             (1, 'ERROR: cannot read evidence\nFAIL: no result'),
                             (1, 'connection refused\nFAIL: unavailable'),
                             (1, ''), (0, 'FAIL: wrong replicas'), (1, 'PASS: ready')]:
            with self.subTest(code=code, output=output):
                with self.assertRaises(RuntimeError):
                    module.verdict(code, output)


if __name__ == '__main__':
    unittest.main()
