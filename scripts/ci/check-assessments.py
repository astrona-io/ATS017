#!/usr/bin/env python3
"""Check quiz identities, answer references and links to registered teaching."""
from pathlib import Path
import sys
import yaml


def validate(root):
    course = yaml.safe_load((root / 'astrona.yaml').read_text())
    entries = [entry for module in course['modules'] for entry in module.get('content', [])]
    readings = {entry['path']: index for index, entry in enumerate(entries) if entry['type'] == 'reading'}
    registered = {entry['path'] for entry in entries if entry['type'] == 'quiz'}
    actual = {str(path.relative_to(root)) for path in root.glob('sections/**/*quiz.yaml')}
    if registered != actual:
        raise ValueError(f'quiz registration mismatch: {registered ^ actual}')
    ids = set()
    count = 0
    for index, entry in enumerate(entries):
        if entry['type'] != 'quiz':
            continue
        path = root / entry['path']
        bank = yaml.safe_load(path.read_text())
        questions = bank.get('questions', [])
        if not questions:
            raise ValueError(f'{path}: empty question bank')
        if 'question_count' in entry and entry['question_count'] != len(questions):
            raise ValueError(f'{path}: question_count differs from bank length')
        for question in questions:
            qid = question['id']
            if qid in ids:
                raise ValueError(f'duplicate question id: {qid}')
            ids.add(qid)
            options = [option['id'] for option in question['options']]
            if len(options) != len(set(options)) or len(options) < 2 or question['correct_option'] not in options:
                raise ValueError(f'{qid}: invalid answer references')
            if not question.get('source_readings'):
                raise ValueError(f'{qid}: no source readings')
            for reading in question['source_readings']:
                if reading not in readings or not (root / reading).is_file():
                    raise ValueError(f'{qid}: missing or unregistered reading {reading}')
                if readings[reading] >= index:
                    raise ValueError(f'{qid}: quiz precedes its teaching {reading}')
            count += 1
    return len(registered), count


if __name__ == '__main__':
    try:
        banks, questions = validate(Path(__file__).resolve().parents[2])
        print(f'PASS: {questions} questions in {banks} registered banks link to preceding teaching')
    except (ValueError, KeyError) as error:
        sys.exit(f'FAIL: {error}')
