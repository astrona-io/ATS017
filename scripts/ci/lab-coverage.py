#!/usr/bin/env python3
"""Validate explicit preparation links and render both directions of coverage."""
from pathlib import Path
import sys
import yaml

ROOT = Path(__file__).resolve().parents[2]


def link(title, path):
    return f'[{title.replace("|", "/")}]({path})'


def technical(path):
    return '/module-' in path and '/course-' in path and 'summary' not in path


def validate(course, coverage):
    entries = [entry for section in course['modules'] for entry in section.get('content', [])]
    positions = {entry['path']: i for i, entry in enumerate(entries)}
    readings = {entry['path']: entry for entry in entries if entry.get('type') == 'reading'}
    labs = {entry['path']: entry for entry in entries if entry.get('type') == 'lab'}
    if coverage.get('version') != 1 or set(coverage.get('labs', {})) != set(labs):
        raise ValueError('TEACHING-COVERAGE.yaml must map every registered lab exactly once')
    used = set()
    for path, mapping in coverage['labs'].items():
        prep = mapping.get('preparation', [])
        if not prep or len(prep) != len(set(prep)):
            raise ValueError(f'{path}: preparation must contain unique reading paths')
        scope = path.split('/labs/')[0] if '/module-' in path else path.split('/capstone/')[0]
        for reading in prep:
            if reading not in readings or not technical(reading):
                raise ValueError(f'{path}: unknown technical reading {reading}')
            if positions[reading] >= positions[path]:
                raise ValueError(f'{path}: preparation must precede the lab: {reading}')
            if not reading.startswith(scope + '/'):
                raise ValueError(f'{path}: preparation must belong to the same module or capstone section')
        if '/module-' in path:
            used.update(prep)
    additional = coverage.get('additional_readings', [])
    expected = {path for path in readings if technical(path)} - used
    if len(additional) != len(set(additional)) or set(additional) != expected:
        raise ValueError('additional_readings must list exactly the technical readings without a module-lab link')
    return readings, labs


def render(root=ROOT):
    course = yaml.safe_load((root / 'astrona.yaml').read_text())
    coverage = yaml.safe_load((root / 'TEACHING-COVERAGE.yaml').read_text())
    readings, labs = validate(course, coverage)
    lines = ['# Lab coverage', '',
             'Generated from `TEACHING-COVERAGE.yaml`, course registration and grader descriptions. '
             'Run `python3 scripts/ci/lab-coverage.py --write` after changing them.', '',
             'Preparation links identify teaching needed for the task. They do not claim that '
             'every skill in a linked lesson is graded. See [coverage review](COVERAGE-REVIEW.md) '
             'for practical gaps and fixture limits. A map is not a runtime test result.', '',
             '## Labs and their preparation', '',
             '| Preparation | Independent task and starting state | Graded result | Runtime and lifecycle |',
             '| --- | --- | --- | --- |']
    reverse = {path: [] for path in readings if technical(path)}
    for path, entry in labs.items():
        config = yaml.safe_load((root / path / 'config.yaml').read_text())
        validation = config.get('validation', {})
        graders = ([validation['script']] if validation.get('script') else []) + validation.get('scripts', [])
        descriptions = '; '.join(link(g.get('description') or g['name'], path + '/' + g['source']) for g in graders)
        preparation = coverage['labs'][path]['preparation']
        prep = '<br>'.join(link(readings[p]['title'], p) for p in preparation)
        task = link(entry['title'], path + '/question.md')
        runtime = config['runtime']['type']
        lifecycle = link(runtime + ' reference lifecycle', path + '/config.yaml')
        lines.append(f'| {prep} | {task} | {descriptions} | {lifecycle} |')
        if '/module-' in path:
            for reading in preparation:
                reverse[reading].append(task)
    lines += ['', '## Readings and their module labs', '',
              'Section capstones integrate several modules and are listed above. '
              'They do not make every preceding reading a separately graded skill.', '',
              '| Technical reading | Related module task |', '| --- | --- |']
    for path, tasks in reverse.items():
        result = '<br>'.join(tasks) if tasks else 'Supporting concepts or ungraded practice; no module-lab link'
        lines.append(f"| {link(readings[path]['title'], path)} | {result} |")
    lines += ['', 'Module labs check the unfinished state, apply the reference solution and '
              'run live graders. Each configuration records its waits and any deliberate '
              'failure cases. GitHub Actions runs each selected environment on a separate '
              'runner and requires the aggregate `all environments pass` job.', '']
    return '\n'.join(lines)


if __name__ == '__main__':
    try:
        expected = render()
    except (ValueError, KeyError) as error:
        sys.exit(f'FAIL: {error}')
    output = ROOT / 'LAB-COVERAGE.md'
    if '--write' in sys.argv:
        output.write_text(expected)
    elif not output.exists() or output.read_text() != expected:
        sys.exit('FAIL: regenerate LAB-COVERAGE.md with python3 scripts/ci/lab-coverage.py --write')
    else:
        print('PASS: explicit teaching links and both coverage directions are current')
