import json,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def run(*args):return subprocess.check_output(['kubectl','-n','starfleet',*args],text=True).strip()
def get(*args):return json.loads(run('get',*args,'-o','json'))
def check(ok,msg):
    if not ok:sys.exit('FAIL: '+msg)
original=json.loads((ROOT/'initial-statefulset.json').read_text())
sts=get('statefulset','probe')
check(sts['metadata']['uid']==original['metadata']['uid'],'preserve the original StatefulSet')
check(sts['spec'].get('persistentVolumeClaimRetentionPolicy')=={'whenScaled':'Retain','whenDeleted':'Retain'},'retain claims on scale-down and deletion')
for key in ('template','volumeClaimTemplates','serviceName','selector'):
    check(sts['spec'][key]==original['spec'][key],f'preserve {key}')
check(sts['spec']['replicas']==2,'finish with two replicas')
claims=json.loads((ROOT/'initial-claims.json').read_text())['items']
def retained():
    for old in claims:
        current=get('pvc',old['metadata']['name'])
        check(current['metadata']['uid']==old['metadata']['uid'] and current['spec']['volumeName']==old['spec']['volumeName'],'preserve each claim and bound volume')
        check(current['status']['phase']=='Bound','claims must remain Bound')
retained()
for attempt in range(60):
    if all(not get('pvc',x['metadata']['name'])['metadata'].get('ownerReferences') for x in claims):break
    time.sleep(2)
else:sys.exit('FAIL: claims still have deletion owner references')
# The grader exercises the same scale-down and replacement taught in the lesson.
run('scale','statefulset','probe','--replicas=1')
try:
    run('wait','--for=delete','pod/probe-1','--timeout=120s')
    retained()
finally:
    run('scale','statefulset','probe','--replicas=2')
run('rollout','status','statefulset/probe','--timeout=180s')
old_uid=get('pod','probe-0')['metadata']['uid']
run('delete','pod','probe-0','--wait=true')
run('rollout','status','statefulset/probe','--timeout=180s')
check(get('pod','probe-0')['metadata']['uid']!=old_uid,'probe-0 must be replaced')
retained()
for ordinal in (0,1):
    check(run('exec',f'probe-{ordinal}','--','cat','/data/record')==(ROOT/f'record-{ordinal}').read_text(),'original data must survive on both replicas')
print('PASS: original claims and data survive scale-down and Pod replacement')
