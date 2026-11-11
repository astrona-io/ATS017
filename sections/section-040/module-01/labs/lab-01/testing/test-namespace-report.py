"""Exercise the full report grader with controlled Kubernetes responses."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

GRADER = Path(__file__).resolve().parents[1] / 'validation/validate-namespace-costs.sh'
KUBECTL = '''
import json, os, sys
args = sys.argv[1:]
data = json.load(open(os.environ['REPORT_FIXTURE']))
if '--raw' in args:
    print(json.dumps(data['allocation']))
elif 'configmap' in args:
    name = args[args.index('configmap') + 1]
    fields = data['window'] if name == 'report-window' else data['report']
    if '-o' in args:
        key = args[args.index('-o') + 1].split('.data.')[1].split('}')[0]
        print(fields.get(key, ''), end='')
elif 'deploy' in args:
    namespace = args[args.index('-n') + 1]
    print(data['cpu'][namespace], end='')
else:
    sys.exit('unexpected kubectl request: ' + repr(args))
'''


def fixture():
    return {'window': {'window': '1000,1300'},
            'report': {'window': '1000,1300', 'starfleet': '1', 'outpost': '3'},
            'allocation': {'data': [{'starfleet': {'totalCost': 1, 'name': 'starfleet'},
                                     'outpost': {'totalCost': 3, 'name': 'outpost'}}]},
            'cpu': {'starfleet': '100m', 'outpost': '500m'}}


class ReportTests(unittest.TestCase):
    def grade(self, data):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            kubectl = root / 'kubectl'
            kubectl.write_text('#!' + sys.executable + '\n' + KUBECTL)
            kubectl.chmod(0o755)
            source = root / 'fixture.json'
            source.write_text(json.dumps(data))
            environment = dict(os.environ, PATH=directory + os.pathsep + os.environ['PATH'],
                               REPORT_FIXTURE=str(source))
            return subprocess.run(['bash', str(GRADER)], env=environment, text=True,
                                  capture_output=True, timeout=20)

    def test_current_individual_costs(self):
        result = self.grade(fixture())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('PASS:', result.stdout)

    def test_stale_window_wrong_population_and_workload_changes(self):
        for fault in ['stale', 'same total', 'missing namespace', 'overflow', 'changed request']:
            data = fixture()
            if fault == 'stale':
                data['report']['window'] = '100,400'
            elif fault == 'same total':
                data['report'].update(starfleet='2', outpost='2')
            elif fault == 'missing namespace':
                del data['allocation']['data'][0]['outpost']
            elif fault == 'overflow':
                data['report']['starfleet'] = '1e999'
            else:
                data['cpu']['outpost'] = '10m'
            with self.subTest(fault=fault):
                result = self.grade(data)
                self.assertEqual(result.returncode, 1)
                self.assertIn('FAIL:', result.stdout)
                self.assertNotIn('PASS:', result.stdout)


if __name__ == '__main__':
    unittest.main()
