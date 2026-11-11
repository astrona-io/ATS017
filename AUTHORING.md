# Course and lab maintenance

Read CLAUDE.md for course structure, version pins and renderer conventions. Keep each module independent. Place a lab's question immediately before its lab entry and after all required preparation. Teach a procedure before asking the learner to produce its evidence. Do not duplicate lab launch commands in reading pages.

Maintain TEACHING-COVERAGE.yaml when adding, moving or changing labs. Map only relevant preparation; list technical readings without a module-lab link in additional_readings. Review the graded behavior as well as the links. Update COVERAGE-REVIEW.md when a practical gap closes or a fixture limit changes. Regenerate LAB-COVERAGE.md with python3 scripts/ci/lab-coverage.py --write.

Prefer one fault or observable outcome per module lab, usually three to five tasks. Split unrelated outcomes and add their preparation in the same change. Keep capstones for integration. Estimate duration from the work and required waits, not a target label. Preserve published paths and identifiers unless an actual collision requires a documented correction.

Choose kind for Kubernetes behavior and QEMU for work requiring a separate kernel or host. Bootstrap every environment from scratch. Keep testing files inside the lab so exported labs do not depend on a sibling checkout. Put the unfinished-state check first in testing.init, then the reference solution and bounded readiness waits. When graders change, update the GRADERS list in testing/verify-start.py. Its common logic lives in scripts/ci/start-state.py; keep copies aligned when changing that logic.

A grader must distinguish a wrong answer from an unavailable dependency. Pair denial probes with allowed controls, verify recorded evidence against live identities, and reject missing, stale or non-finite data. Add regression tests for meaningful failure cases. An API readiness check does not excuse a grader that hides connection errors.

Run the structure, coverage and regression checks before pushing. Run astrona validate and astrona test for changed labs; run scripts/ci/test-playground.sh for changed playgrounds. CI discovers changed sections, and changes to shared scripts, course registration or the coverage map select every environment. The all environments pass job depends on discovery and all selected runtimes. Keep failure diagnostics and report external failures separately.

Continue on the existing review branch and PR, with separate commits for distinct changes. Do not merge automatically. Record what actually ran and which checks remain unverified in the PR description.
