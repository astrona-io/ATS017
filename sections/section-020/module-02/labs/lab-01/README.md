---
estimated_duration: 20m
---
# Lock Down A Tenant Namespace

Repair a combined-selector mistake and isolate a tenant in both directions.
The lab uses the same default kindnet setup as the section capstone. It
preloads every workload image and uses kubectl on the Astrona terminal.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-02/labs/lab-01
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-020/module-02/labs/lab-01
astrona destroy ats-017-lab-020-02
```

The walkthrough uses watch mode while building the answer. A plain submit
finishes the attempt and removes the environment.

Four validators check isolation, DNS, frontend access and monitoring.
They read live objects and test fresh connections from Pods in all three
namespaces. Local listener checks keep missing servers from passing as
denied traffic. All validators require the missing default-deny policy,
so each fails on the untouched start state. DNS grading checks both
protocol permissions and observes actual name resolution from all three
tenant workloads; it does not force a TCP DNS exchange.

Author status: built without booting on 2026-11-06. Offline validation is
recorded in the course build state; live startup and grading remain untested.
