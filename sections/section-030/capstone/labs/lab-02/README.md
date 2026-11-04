---
estimated_duration: 35m
---
# Combine VPA, Right-Sizing And HPA

Hands-on practice for Kubernetes 1.35.8 and Vertical Pod Autoscaler (VPA) 1.7.3. Environment preparation installs the official VPA chart 0.12.0 as plumbing. The terminal needs kubectl and Helm 4.x; graded environments also use Python 3 for live-state checks. All container images, including certificate-generation plumbing, are listed in the environment configuration for preloading.

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/capstone/labs/lab-02
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-030/capstone/labs/lab-02
astrona destroy ats-017-capstone-030-02
```

Built for astrona CLI v0.4.14. Author checks are offline only: configuration validation, shell syntax, YAML parsing and Helm rendering. This environment has not been booted or tested against a live cluster.
