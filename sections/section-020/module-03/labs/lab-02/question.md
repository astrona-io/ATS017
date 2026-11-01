---
estimated_duration: 15m
---

# Question

Solve this question on: `terminal`

The `probe-storage` pod in the namespace `starfleet` keeps a file at `/data/message.txt` on the claim `probe-data`. The claim uses the StorageClass `standard`, so the volume behind it has the reclaim policy `Delete`. The team must not lose this file if someone deletes the claim by mistake.

Do these two things:

1.  Make the **existing** volume behind `probe-data` keep its storage when the claim is deleted.
2.  Make `standard-retain` the default StorageClass, so that a new claim without `storageClassName` receives it. `standard` must stop being a default.

Constraints:

* Do not delete or recreate `probe-data` or `probe-storage`.
* Do not move or rewrite the file. It must still read `saved-by-probe`.
* Do not delete either StorageClass.

The grader checks that the claim is still `Bound`, that the file is intact, and that the volume's reclaim policy is `Retain`. Then it checks that `standard-retain` is the only default class and creates a claim without a class to see which class it receives.
