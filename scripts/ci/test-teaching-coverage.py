#!/usr/bin/env python3
"""Reject missing, late and unrelated preparation in course coverage maps."""
import importlib.util
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('coverage_map', ROOT / 'scripts/ci/lab-coverage.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CoverageTests(unittest.TestCase):
    def setUp(self):
        self.course = yaml.safe_load((ROOT / 'astrona.yaml').read_text())
        self.coverage = yaml.safe_load((ROOT / 'TEACHING-COVERAGE.yaml').read_text())
        self.lab = next(iter(self.coverage['labs']))

    def test_current_map(self):
        module.validate(self.course, self.coverage)

    def test_missing_lab(self):
        del self.coverage['labs'][self.lab]
        with self.assertRaisesRegex(ValueError, 'every registered lab'):
            module.validate(self.course, self.coverage)

    def test_unknown_preparation(self):
        self.coverage['labs'][self.lab]['preparation'] = ['missing.md']
        with self.assertRaisesRegex(ValueError, 'unknown technical reading'):
            module.validate(self.course, self.coverage)

    def test_late_preparation(self):
        prep = self.coverage['labs'][self.lab]['preparation'][0]
        for section in self.course['modules']:
            content = section.get('content', [])
            reading = next((e for e in content if e['path'] == prep), None)
            if reading:
                content.remove(reading)
                content.append(reading)
                break
        with self.assertRaisesRegex(ValueError, 'must precede'):
            module.validate(self.course, self.coverage)

    def test_unmapped_reading_hidden(self):
        self.coverage['additional_readings'].append('missing.md')
        with self.assertRaisesRegex(ValueError, 'additional_readings'):
            module.validate(self.course, self.coverage)


if __name__ == '__main__':
    unittest.main()
