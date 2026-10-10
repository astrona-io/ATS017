# How This Course Is Made

You will trust a course more when you know how it is built. This page tells you how the content is written and checked, who is behind it, and how you can help make it better.

## How the content is written

The course targets one version of Kubernetes. Everything is built and checked on **Kubernetes 1.35**, the version the exam uses, so when a page says how Kubernetes behaves, it means that version. Each add-on, such as metrics-server, Envoy Gateway, the Vertical Pod Autoscaler and OpenCost, is also pinned to one version.

Facts come from real sources. They are checked against the official Kubernetes documentation first, because that is the documentation you may open during the exam, and then against the documentation of each add-on. Each page then explains everything you need on the page itself, so you never have to leave the course to look something up.

Command output is real, too. When a page shows output, it comes from a real run. If the output is shortened, the page says so. If there was no real run to copy from, the page describes the result in words instead of making up output. Cost figures are a special case: a cluster on your machine has no cloud bill, so OpenCost uses a default price list, and the pages say so.

The same care goes into the graded labs, because their graders check behaviour. Every graded lab checks what really happens in the cluster: where a pod runs, whether a request gets through, how many replicas a workload has, or whether the cluster rejects a pod that breaks a quota. Many graders also reject the change that only hides the problem, such as deleting a NetworkPolicy instead of allowing one flow. Each lab also has a reference solution that is run against its own grader, so the grader is known to accept a correct answer.

The pages are written in plain English, for people who are not native English speakers and have no university degree. Words are written out in full, and each technical term gets a short, plain definition the first time it appears. The pages use the real technical terms, not metaphors, because those are the words you meet in the product, the documentation and the exam.

Finally, large parts of this course are drafted and edited with the help of AI tools. A maintainer reviews every change before it is published, and the technical checks above apply to all content, however it was written.

## Maintainers

A small group of people builds and looks after the course. The core maintainer is **Paris Nakita Kejser** ([@parisnakitakejser](https://github.com/parisnakitakejser)).

Many others have helped along the way. Every person who has changed the course is listed on the GitHub contributors page:
[github.com/astrona-io/ATS017/graphs/contributors](https://github.com/astrona-io/ATS017/graphs/contributors)

## Found a mistake? Report it

Even with these checks, mistakes slip through. If a command fails, a page says something wrong, or a lab grades a correct answer as wrong, please tell us. Every report makes the course better for the next learner. A good report takes four steps:

1. Open a new issue on GitHub: [github.com/astrona-io/ATS017/issues](https://github.com/astrona-io/ATS017/issues).
2. Say which page or lab it is (the file path is the easiest, for example `sections/section-010/module-01/labs/lab-01`).
3. Paste the command you ran and what you saw. Leave out passwords, tokens, private keys or anything else private.
4. Say what you expected to happen instead.

Want to fix it yourself? Pull requests are welcome on the same repository.

## License

The course is published under the [Apache License 2.0](https://github.com/astrona-io/ATS017/blob/main/LICENSE). You are welcome to use it, share it and build on it under the terms of that license.
