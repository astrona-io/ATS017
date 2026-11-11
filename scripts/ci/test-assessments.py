#!/usr/bin/env python3
"""Reject broken assessment navigation and answer references."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import yaml

spec = importlib.util.spec_from_file_location('assessments', Path(__file__).with_name('check-assessments.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class AssessmentTests(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        (self.root / 'sections').mkdir()
        (self.root / 'sections/lesson.md').write_text('# Lesson\n')
        self.entries = [{'type': 'reading', 'path': 'sections/lesson.md'}, {'type': 'quiz', 'path': 'sections/quiz.yaml', 'question_count': 1}]
        self.question = {'id': 'q1', 'source_readings': ['sections/lesson.md'], 'options': [{'id': 'a'}, {'id': 'b'}], 'correct_option': 'a'}

    def check(self, questions=None):
        (self.root / 'astrona.yaml').write_text(yaml.safe_dump({'modules': [{'content': self.entries}]}))
        (self.root / 'sections/quiz.yaml').write_text(yaml.safe_dump({'questions': questions or [self.question]}))
        return module.validate(self.root)

    def test_valid(self):
        self.assertEqual(self.check(), (1, 1))

    def test_missing_reading(self):
        self.question['source_readings'] = ['sections/missing.md']
        with self.assertRaisesRegex(ValueError, 'missing or unregistered'):
            self.check()

    def test_quiz_before_teaching(self):
        self.entries.reverse()
        with self.assertRaisesRegex(ValueError, 'precedes'):
            self.check()

    def test_invalid_answer(self):
        self.question['correct_option'] = 'c'
        with self.assertRaisesRegex(ValueError, 'answer references'):
            self.check()

    def test_stale_count(self):
        self.entries[1]['question_count'] = 2
        with self.assertRaisesRegex(ValueError, 'question_count'):
            self.check()

    def test_duplicate_id(self):
        self.entries[1]['question_count'] = 2
        with self.assertRaisesRegex(ValueError, 'duplicate question'):
            self.check([self.question, self.question])

    def test_unregistered_bank(self):
        (self.root / 'sections/extra-quiz.yaml').write_text('questions: []\n')
        with self.assertRaisesRegex(ValueError, 'registration mismatch'):
            self.check()


if __name__ == '__main__':
    unittest.main()
