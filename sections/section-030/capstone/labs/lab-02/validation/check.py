#!/usr/bin/env python3
"""Read live objects and usage. No cluster writes, fixed metrics, or fallback data."""
import json
import re
import subprocess
import sys
from decimal import Decimal

CAPSTONE = True

def require(condition, message):
    if not condition:
        raise ValueError(message)

def get(*arguments):
    flags = [] if '--raw' in arguments else ['-o', 'json']
    return json.loads(subprocess.check_output(['kubectl', *arguments, *flags], text=True))

def quantity(value):
    match = re.fullmatch(r'([0-9]+(?:\.[0-9]+)?)([a-zA-Z]*)', str(value))
    require(match is not None, f'Unsupported or absent resource quantity: {value}')
    suffix = match.group(2)
    factors = {'': 1, 'n': Decimal('0.000000001'), 'u': Decimal('0.000001'),
               'm': Decimal('0.001'), 'k': 1000, 'M': 1000000, 'G': 1000000000,
               'Ki': 1024, 'Mi': 1024**2, 'Gi': 1024**3}
    require(suffix in factors, f'Unsupported resource suffix: {suffix}')
    return Decimal(match.group(1)) * factors[suffix]

def same_resources(actual, expected, label):
    for resource, value in expected.items():
        require(quantity(actual.get(resource, '')) == quantity(value), f'{label}: expected {resource}={value}')

def bounded(resources, label):
    for resource, minimum, maximum in [('cpu', '50m', '300m'), ('memory', '64Mi', '256Mi')]:
        amount = quantity(resources.get(resource, ''))
        require(quantity(minimum) <= amount <= quantity(maximum), f'{label}: {resource} is outside {minimum} to {maximum}')

def controller(name):
    return get('-n', 'starfleet', 'get', 'statefulset' if name == 'probe' else 'deployment', name)

def original_container(workload):
    containers = workload['spec']['template']['spec']['containers']
    require(len(containers) == 1, 'Keep one original container in each workload')
    container = containers[0]
    require(container['image'] == 'ghcr.io/stefanprodan/podinfo:6.15.0', 'Keep the original podinfo image')
    require(not container.get('command') and not container.get('args'), 'Keep the original application process')
    # The API server adds defaults (scheme: HTTP) to the stored probe, so compare only the fields the lab sets.
    http_get = container.get('readinessProbe', {}).get('httpGet') or {}
    require(http_get.get('path') == '/readyz' and http_get.get('port') == 'http', 'Keep the HTTP readiness probe')
    return container

def policies():
    for name, kind in [('probe', 'StatefulSet'), ('scout', 'Deployment')]:
        vpa = get('-n', 'starfleet', 'get', 'vpa', name)
        spec = vpa['spec']
        require(spec['targetRef'] == {'apiVersion': 'apps/v1', 'kind': kind, 'name': name}, f'{name}: wrong targetRef')
        expected_mode = 'Off' if CAPSTONE and name == 'scout' else 'Initial'
        require(spec.get('updatePolicy', {}).get('updateMode') == expected_mode, f'{name}: use {expected_mode}')
        require(not spec.get('startupBoost'), f'{name}: do not add startup boost')
        entries = spec.get('resourcePolicy', {}).get('containerPolicies', [])
        require(len(entries) == 1, f'{name}: use one named container policy')
        policy = entries[0]
        require(policy.get('containerName') == name, f'{name}: policy must name the container')
        require(policy.get('mode', 'Auto') == 'Auto', f'{name}: container scaling must stay enabled')
        require(not policy.get('startupBoost'), f'{name}: do not add startup boost')
        require(sorted(policy.get('controlledResources', [])) == ['cpu', 'memory'], f'{name}: control CPU and memory')
        require(policy.get('controlledValues') == 'RequestsOnly', f'{name}: use RequestsOnly')
        same_resources(policy.get('minAllowed', {}), {'cpu': '50m', 'memory': '64Mi'}, f'{name} minimum')
        same_resources(policy.get('maxAllowed', {}), {'cpu': '300m', 'memory': '256Mi'}, f'{name} maximum')
        recommendations = vpa.get('status', {}).get('recommendation', {}).get('containerRecommendations', [])
        require(len(recommendations) == 1 and recommendations[0]['containerName'] == name, f'{name}: wait for a recommendation')
        bounded(recommendations[0].get('target', {}), f'{name} recommended target')
    vpas = get('-n', 'starfleet', 'get', 'vpa')['items']
    require({item['metadata']['name'] for item in vpas} == {'probe', 'scout'}, 'Keep only VPA probe and scout in starfleet')
    hpas = get('-n', 'starfleet', 'get', 'hpa')['items']
    require(all(CAPSTONE and item['spec']['scaleTargetRef']['name'] == 'scout' and item['spec']['scaleTargetRef']['kind'] == 'Deployment' for item in hpas), 'Do not put an HPA on a VPA-managed workload')

def applied():
    baseline = get('-n', 'kube-system', 'get', 'configmap', 'vpa-lab-start')['data']
    for name in (['probe'] if CAPSTONE else ['probe', 'scout']):
        workload = controller(name)
        container = original_container(workload)
        same_resources(container['resources']['requests'], {'cpu': '500m', 'memory': '512Mi'}, f'{name} unchanged template requests')
        same_resources(container['resources']['limits'], {'cpu': '1', 'memory': '1Gi'}, f'{name} unchanged template limits')
        pods = get('-n', 'starfleet', 'get', 'pods', '-l', f'app={name}')['items']
        pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
        require(len(pods) == 1, f'{name}: keep one Pod')
        pod = pods[0]
        require(pod['metadata']['uid'] != baseline[name], f'{name}: replace the original Pod after a recommendation is available')
        annotation = pod['metadata'].get('annotations', {}).get('vpaUpdates', '')
        require(annotation.startswith(f'Pod resources updated by {name}:') and 'cpu request' in annotation and 'memory request' in annotation, f'{name}: VPA admission did not apply both requests')
        requests = pod['spec']['containers'][0]['resources']['requests']
        bounded(requests, f'{name} live Pod requests')
        same_resources(pod['spec']['containers'][0]['resources']['limits'], {'cpu': '1', 'memory': '1Gi'}, f'{name} Pod limits')
        statuses = pod.get('status', {}).get('containerStatuses', [])
        require(len(statuses) == 1 and statuses[0].get('ready'), f'{name}: wait for the replacement Pod to be Ready')
        same_resources(statuses[0].get('resources', {}).get('requests', {}), requests, f'{name} running container requests')
        require(pod['spec']['containers'][0]['image'] == container['image'], f'{name}: keep the Pod image')

def sizing():
    workload = controller('scout')
    container = original_container(workload)
    same_resources(container['resources']['requests'], {'cpu': '100m', 'memory': '256Mi'}, 'scout reduced template')
    same_resources(container['resources']['limits'], {'cpu': '1', 'memory': '1Gi'}, 'scout unchanged limits')
    pods = get('-n', 'starfleet', 'get', 'pods', '-l', 'app=scout')['items']
    pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
    require(pods, 'scout has no Pods')
    metrics = get('get', '--raw', '/apis/metrics.k8s.io/v1beta1/namespaces/starfleet/pods')['items']
    usage_by_name = {item['metadata']['name']: item for item in metrics}
    for pod in pods:
        same_resources(pod['spec']['containers'][0]['resources']['requests'], {'cpu': '100m', 'memory': '256Mi'}, 'scout live requests')
        require(pod.get('status', {}).get('containerStatuses', [{}])[0].get('ready'), 'Wait for every scout Pod to be Ready')
        require(not pod['metadata'].get('annotations', {}).get('vpaUpdates'), 'scout requests must come from the template, with VPA Off')
        usage = usage_by_name.get(pod['metadata']['name'], {}).get('containers', [])
        require(usage, 'Wait for live scout usage before submitting')
        require(quantity(usage[0]['usage']['memory']) <= quantity('256Mi'), 'scout memory usage exceeds the chosen request')

def hpa():
    autoscaler = get('-n', 'starfleet', 'get', 'hpa', 'scout')
    spec = autoscaler['spec']
    require(spec['scaleTargetRef'] == {'apiVersion': 'apps/v1', 'kind': 'Deployment', 'name': 'scout'}, 'HPA must target Deployment scout')
    require(spec.get('minReplicas') == 1 and spec.get('maxReplicas') == 3, 'HPA bounds must be 1 and 3')
    require(spec.get('metrics') == [{'type': 'Resource', 'resource': {'name': 'cpu', 'target': {'type': 'Utilization', 'averageUtilization': 60}}}], 'HPA must use only CPU Utilization at 60 percent')
    require(spec.get('behavior', {}).get('scaleDown', {}).get('stabilizationWindowSeconds') == 60, 'Use a 60-second scale-down stabilization window')
    require(get('-n', 'starfleet', 'get', 'vpa', 'scout')['spec']['updatePolicy']['updateMode'] == 'Off', 'Keep scout VPA Off before enabling the HPA')

try:
    {'policies': policies, 'applied': applied, 'sizing': sizing, 'hpa': hpa}[sys.argv[1]]()
    print('OK: hpa configuration' if sys.argv[1] == 'hpa' else f'PASS: {sys.argv[1]}')
except (ValueError, KeyError, IndexError, subprocess.CalledProcessError) as error:
    print(f'FAIL: {sys.argv[1]}: {error}')
    sys.exit(1)
