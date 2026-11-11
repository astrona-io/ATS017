import copy,json,subprocess,sys,time
from decimal import Decimal
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
NAME='scout-underprovisioned'
UNDER=True
def get(*args):return json.loads(subprocess.check_output(['kubectl','-n','starfleet',*args,'-o','json'],text=True))
def check(ok,msg):
    if not ok:sys.exit('FAIL: '+msg)
def quantity(value):
    units={'Ki':1024,'Mi':1024**2,'Gi':1024**3,'Ti':1024**4,'n':1e-9,'u':1e-6,'m':.001,'k':1000,'M':1000**2,'G':1000**3}
    for suffix,factor in units.items():
        if value.endswith(suffix):return Decimal(value[:-len(suffix)])*Decimal(str(factor))
    return Decimal(value)
original=json.loads((ROOT/'original-deployment.json').read_text());live=get('get','deploy',NAME)
check(live['metadata']['uid']==original['metadata']['uid'],'preserve the Deployment')
a=copy.deepcopy(original['spec']);b=copy.deepcopy(live['spec'])
a['template']['spec']['containers'][0].pop('resources');b['template']['spec']['containers'][0].pop('resources')
# kubectl set resources may update this diagnostic annotation; it is not workload configuration.
for spec in (a,b):spec.get('template',{}).get('metadata',{}).get('annotations',{}).pop('kubectl.kubernetes.io/restartedAt',None)
check(a==b,'change only resource requests and limits')
service=get('get','svc',NAME);old=json.loads((ROOT/'original-service.json').read_text())
check(service['metadata']['uid']==old['metadata']['uid'] and service['spec']==old['spec'],'preserve the Service')
resources=live['spec']['template']['spec']['containers'][0].get('resources',{})
request=quantity(resources.get('requests',{}).get('memory','0'));limit=quantity(resources.get('limits',{}).get('memory','0'));cpu=quantity(resources.get('requests',{}).get('cpu','0'))
check(limit>=request and limit>0,'keep a memory limit at least as large as the request')
if UNDER:check(request>=100*1024**2,'raise the memory request to cover the stress workload')
else:
    check(Decimal('.01')<=cpu<=Decimal('.2'),'CPU request must be 10m through 200m')
    check(20*1024**2<=request<=256*1024**2 and limit<=512*1024**2,'reduce oversized memory reservations within the task bounds')
subprocess.run(['kubectl','-n','starfleet','rollout','status','deploy/'+NAME,'--timeout=180s'],check=True)
def ready_pod():
    pods=get('get','pods','-l','app='+NAME)['items']
    pods=[p for p in pods if not p['metadata'].get('deletionTimestamp') and all(c.get('ready') for c in p['status'].get('containerStatuses',[])) and p['status'].get('containerStatuses')]
    check(len(pods)==1,'need one current Ready Pod')
    return pods[0]
pod=ready_pod();name=pod['metadata']['name']
usage=None
for attempt in range(30):
    p=subprocess.run(['kubectl','get','--raw',f'/apis/metrics.k8s.io/v1beta1/namespaces/starfleet/pods/{name}'],text=True,capture_output=True)
    if p.returncode==0:
        metrics=json.loads(p.stdout);usage=quantity(next(c for c in metrics['containers'] if c['name']=='scout')['usage']['memory']);break
    time.sleep(3)
check(usage is not None,'live memory metrics did not become available')
check(request>=usage,'memory request must cover observed usage')
if UNDER:check(request<=usage*3,'memory request must not exceed three times observed usage')
before=pod['status']['containerStatuses'][0]['restartCount']
time.sleep(30)
after=ready_pod()
check(after['metadata']['uid']==pod['metadata']['uid'] and after['status']['containerStatuses'][0]['restartCount']==before,'Pod must remain Ready without replacement or restart during observation')
print('PASS: resource requests cover measured usage and the workload remains stable')
