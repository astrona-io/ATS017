"""Reject invalid allocation values and compare each reported measurement."""
import importlib.util
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[1] / 'validation/cost-values.py'
spec = importlib.util.spec_from_file_location('cost_values', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CostTests(unittest.TestCase):
    def test_nonfinite_negative_and_missing_values(self):
        for value in ['nan', 'inf', '-inf', '1e999', '-1', '', None, True]:
            with self.subTest(value=value):
                with self.assertRaises((ValueError, TypeError)):
                    module.number(value)

    def test_scientific_notation_and_json_field_order(self):
        document = {'data': [{'starfleet': {'totalCost': 1.2e+3, 'name': 'starfleet'}}]}
        self.assertEqual(module.allocation(document, 'starfleet', 'totalCost'), 1200)
        self.assertTrue(module.within('1.2E+3', 1200, 0.00002))

    def test_missing_population_wrong_name_or_multiple_windows(self):
        for document in [{'data': [{}]}, {'data': []}, {'data': [{}, {}]},
                         {'data': [{'starfleet': {'name': 'outpost', 'totalCost': 1}}]},
                         {'data': [{'starfleet': {'name': 'starfleet', 'totalCost': '1'}}]}]:
            with self.subTest(document=document):
                with self.assertRaises((ValueError, KeyError)):
                    module.allocation(document, 'starfleet', 'totalCost')

    def test_relative_and_rounding_tolerance(self):
        self.assertTrue(module.within(1.1, 1, 0.00002))
        self.assertFalse(module.within(1.2, 1, 0.00002))
        self.assertTrue(module.within(0.00001, 0, 0.00002))
        self.assertFalse(module.within(0.001, 0, 0.00002))
        # A correct combined total cannot excuse either incorrect namespace.
        self.assertEqual(sum([1, 3]), sum([2, 2]))
        self.assertFalse(module.within(2, 1, 0.00002))
        self.assertFalse(module.within(2, 3, 0.00002))
        for reported, expected in [('1e999', 1), (1, '1e999'), ('1e999', '1e999')]:
            with self.subTest(reported=reported, expected=expected):
                with self.assertRaises(ValueError):
                    module.within(reported, expected, 0.00002)


if __name__ == '__main__':
    unittest.main()
