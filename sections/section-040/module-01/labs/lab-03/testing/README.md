# Offline Author Checks

Run `astrona validate -c sections/section-040/module-01/labs/lab-03`, parse the YAML,
and run `bash -n` on the shell scripts. Do not boot this lab during the
2026-11-04 authoring work. Live startup, plugin compatibility and grading remain untested.

Bootstrap leaves the original rates and creates no graded result files. Each
validator therefore fails on the untouched start state. The reference solution
changes the ConfigMap, reloads OpenCost and writes all three reports. The cost
validator repeats a closed window. The pod validator repeats the saved
Prometheus evaluation time. The error validator reads the target again.
