#!/usr/bin/env python3
"""Check registration, local files and the order of lifecycle hooks."""
from pathlib import Path
import ast
import sys
import yaml

ROOT = Path(__file__).resolve().parents[2]


def validate(root):
    course = yaml.safe_load((root / 'astrona.yaml').read_text())
    entries = [e for section in course['modules'] for e in section.get('content', [])]
    paths = [e['path'] for e in entries]
    if len(paths) != len(set(paths)):
        raise ValueError('course content paths must be unique')
    for path in paths:
        if not (root / path).exists():
            raise ValueError(f'missing registered content: {path}')
    labs = {e['path'] for e in entries if e['type'] == 'lab'}
    actual = {str(p.parent.relative_to(root)) for p in root.glob('sections/**/labs/lab-*/config.yaml')}
    if labs != actual:
        raise ValueError(f'lab registration mismatch: {labs ^ actual}')
    names = set()
    for config in root.glob('sections/**/config.yaml'):
        if '/labs/lab-' not in str(config) and config.parent.name != 'playground':
            continue
        cfg = yaml.safe_load(config.read_text())
        name = cfg['metadata']['name']
        if name in names:
            raise ValueError(f'duplicate environment name: {name}')
        names.add(name)
        if cfg['runtime']['type'] not in ('kind', 'qemu'):
            raise ValueError(f'{config}: unsupported runtime')
        for stage in ('bootstrap', 'testing', 'teardown', 'validation'):
            block = cfg.get(stage, {})
            items = block.get('init', []) + block.get('scripts', [])
            if block.get('script'):
                items += [block['script']]
            for item in items:
                if item.get('type') in ('file', 'folder') and not (config.parent / item['source']).exists():
                    raise ValueError(f'{config}: missing {stage} source {item["source"]}')
        if str(config.parent.relative_to(root)) not in labs:
            continue
        init = cfg.get('testing', {}).get('init', [])
        if not init or init[0].get('source') != 'testing/verify-start.sh' or len(init) < 2:
            raise ValueError(f'{config}: unfinished-state check must precede the solution')
        validation = cfg['validation']
        graders = ([validation['script']] if validation.get('script') else []) + validation.get('scripts', [])
        sources = [g['source'] for g in graders]
        if not sources:
            raise ValueError(f'{config}: no graders')
        tree = ast.parse((config.parent / 'testing/verify-start.py').read_text())
        checks = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'GRADERS' for t in node.targets))
        if checks != sources:
            raise ValueError(f'{config}: unfinished-state grader list differs from validation')
        path = str(config.parent.relative_to(root))
        position = paths.index(path)
        if position == 0 or paths[position - 1] != path + '/question.md':
            raise ValueError(f'{path}: question must immediately precede its lab')
    return len(labs), len(names) - len(labs)


if __name__ == '__main__':
    try:
        labs, playgrounds = validate(ROOT)
        print(f'PASS: {labs} labs and {playgrounds} playgrounds have valid registration and lifecycle files')
    except (ValueError, KeyError, StopIteration) as error:
        sys.exit(f'FAIL: {error}')
