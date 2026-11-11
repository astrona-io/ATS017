"""Require an explicit grader rejection before applying the reference solution."""
from pathlib import Path
import re
import subprocess
import sys


def verdict(code, output):
    # Missing objects can be the assigned work; the grader must still emit FAIL.
    diagnostics = re.sub(r'^Error from server \(NotFound\): [\w.]+ "[^"\n]+" not found$',
                         '', output, flags=re.M)
    # A shell failure, timeout or Python exception is not a graded rejection.
    if re.search(r'Traceback \(most recent call last\)|command not found|No such file or directory|^ERROR\b|connection refused|Unable to connect to the server|TLS handshake timeout', diagnostics, re.M | re.I):
        raise RuntimeError('grader reported an execution or connection error')
    failed = bool(re.search(r'^FAIL(?:\b|:)', output, re.M))
    passed = bool(re.search(r'^PASS(?:\b|:)', output, re.M))
    if code == 1 and failed:
        return False
    if code == 0 and passed and not failed:
        return True
    raise RuntimeError(f'grader exit {code} has no consistent PASS or FAIL verdict')


def ready():
    subprocess.run(['kubectl', '--request-timeout=15s', 'get', '--raw=/readyz'],
                   check=True, timeout=20, stdout=subprocess.DEVNULL)


def verify(lab, graders):
    ready()
    for source in graders:
        path = lab / source
        if not path.is_file():
            raise RuntimeError(f'missing grader: {path}')
        print(f'Checking unfinished state with {source}', flush=True)
        result = subprocess.run(['bash', str(path)], cwd=lab, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
        print(result.stdout, end='', flush=True)
        passed = verdict(result.returncode, result.stdout)
        ready()
        if not passed:
            print('PASS: the ready environment has unfinished graded work')
            return
    raise RuntimeError('all graders passed before the reference solution')


GRADERS = ['validation/validate.sh']

if __name__ == '__main__':
    try:
        verify(Path(__file__).resolve().parents[1], GRADERS)
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        sys.exit(f'ERROR: unfinished-state check: {error}')
