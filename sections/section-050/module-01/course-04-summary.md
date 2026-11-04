# Summary

A shared cluster needs limits at two levels: the whole namespace, and each container in it. This module covered both and the order in which the API server applies them.

## What you learned

A ResourceQuota caps what all workloads of one namespace use together. Its `spec.hard` field lists compute (`requests.cpu`, `requests.memory`, `limits.cpu`, `limits.memory`), storage (`requests.storage`, `persistentvolumeclaims`) and object counts (`pods`, `count/<resource>`). `kubectl describe resourcequota` shows used against hard. The quota is checked when an object is created, so it never stops pods that already run.

A rejected pod gives one of two messages. `exceeded quota` names the resource, the amount requested, the amount used and the cap. `must specify` means the quota counts a compute resource that the pod does not declare. A Deployment never shows the message in the terminal. It appears in the `ReplicaFailure` condition of the Deployment and in the `FailedCreate` events of its ReplicaSet.

A storage quota counts claims and their total requested capacity. Setting `persistentvolumeclaims` to zero blocks new claims but leaves existing ones in place. Stop the workload that mounts a claim before deleting it. A reverted Git commit can still show which namespace requested storage, because the revert preserves the earlier history.

A LimitRange of `type: Container` sets `defaultRequest`, `default`, `min`, `max` and `maxLimitRequestRatio` for each container. The LimitRange step runs before the quota step, so defaults make pods without resources acceptable to a compute quota. The LimitRange only changes pods created after it exists, and a `max` without a `default` becomes the default limit.

- A compute quota requires every new pod to declare the resources it counts.
- A LimitRange default fills in missing values before the quota check.
- A quota and a LimitRange never change pods that already run.
- Read the `ReplicaFailure` condition or the ReplicaSet events to find a quota rejection.

<!-- astrona:playground:destroy -->
