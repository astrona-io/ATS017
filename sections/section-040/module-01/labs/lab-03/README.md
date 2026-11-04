---
estimated_duration: 25m
---

# Update OpenCost Pricing And Inspect Its Data

The `starfleet` team needs new internal rates and evidence that its cost data
sources work. Change the pricing model, read the active prices, use the
`kubectl cost` plugin and save two Prometheus results. One scrape target
fails on purpose and stays down.

## Launching the Lab

Bootstrap installs the pinned plugin on the terminal, installs the monitoring
charts and waits for a closed cost window. It can take 12 to 20 minutes.

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/labs/lab-03
astrona submit --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-040/module-01/labs/lab-03
astrona destroy ats-017-lab-040-01-03
```

Built without booting on 2026-11-04. See the offline author checks in `testing/`.
