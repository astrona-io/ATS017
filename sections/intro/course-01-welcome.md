# Welcome To The Course

This course trains you for the **Platform Architecture and Infrastructure** part of the **Certified Cloud Native Platform Engineer (CNPE)** exam. That part is 15% of the exam. This page tells you who the course is for, what you can do at the end, which words and example app it uses, and how its pages fit together.

## Who this course is for

You know your way around Kubernetes: namespaces, Deployments, Services, pod labels, `kubectl get`, `kubectl describe`, `kubectl logs` and `kubectl exec`. You can read and apply a YAML manifest. You do not need to have run a shared cluster for many teams before. Each new idea is explained the first time it appears.

## What you can do at the end

The exam is hands-on. You get live clusters and a list of 15 to 20 tasks, and you have two hours. During the exam you may open the Kubernetes documentation and a short reference page for the tool in each task, and nothing else. So this course does not ask you to remember words. It asks you to change a cluster, prove the change works, and know where each field is described in the Kubernetes documentation. The exam groups this part into three topics, and each one turns into a set of skills you will practise.

The first topic is **applying platform architecture best practices for networking, storage and compute**. You will learn to:

- Set CPU and memory requests and limits, and read the quality of service (QoS) class Kubernetes gives a pod.
- Place pods on the right nodes with node affinity, taints and tolerations, and spread them across zones.
- Route traffic into the cluster with the Gateway API.
- Allow only the traffic a workload needs with a NetworkPolicy.
- Give a workload storage through a StorageClass and a PersistentVolumeClaim.

The second topic is **using cost management solutions for right-sizing and scaling**. You will learn to:

- Scale a workload to its load with a HorizontalPodAutoscaler (HPA).
- Read CPU and memory recommendations from the Vertical Pod Autoscaler (VPA) and apply them.
- Read the cost of each namespace and workload with OpenCost, and find capacity that nobody uses.

The third topic is **optimizing multi-tenancy resource usage**: sharing one cluster fairly between teams. You will learn to:

- Cap a team's namespace with a ResourceQuota, and set default requests and limits with a LimitRange.
- Decide which pods run first when the cluster is full, with PriorityClasses and quota scopes.

Everything is built and checked on **Kubernetes 1.35**, the version the exam uses.

## The words this course uses

The pages use Kubernetes' own terms and the terms of each tool, because those are the words you meet in the product, the documentation and the exam. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **pod** runs one copy of an application, and a **namespace** groups pods and other objects inside the cluster. A **node** is one machine in the cluster that runs pods. The **scheduler** is the control plane component that picks a node for each new pod. The **kubelet** is the agent on each node that starts the pod's containers and reports their state.

Two numbers on every container decide most of this course:

| Field | What it does |
| --- | --- |
| `resources.requests` | The CPU and memory the scheduler reserves for the container on a node |
| `resources.limits` | The most CPU and memory the container may use |

A **tenant** is one team or customer that shares the cluster with others. In this course each tenant has its own namespace.

## The example app in your playground

Every playground and lab runs the same small app, and its names come from space. The `starfleet` namespace belongs to the main team, and the `outpost` namespace belongs to a second team. `scout` is an HTTP API (podinfo) on port `9898`. It has endpoints that use CPU or hold memory on demand, so you can create load for the autoscalers. `probe` is an HTTP echo server on port `8080`, used as a second backend. You send your test requests from `shuttle`, a client pod with `curl`. A few modules add `bridge`, an nginx front end.

The names are only names. The pages always describe what each object really is, and they always tell you the namespace to use.

## How the course is laid out

The course has five sections. They go from one workload to many teams: size and place one workload, connect it and give it storage, scale it to its load, see what it costs, and last share the cluster fairly.

| Section | What it covers |
| --- | --- |
| 010 | Compute Placement And Sizing |
| 020 | Networking And Storage |
| 030 | Right-Sizing And Autoscaling |
| 040 | Cost Visibility With OpenCost |
| 050 | Multi-Tenancy Resources |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a given state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several tasks at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, the real output, and then what that output shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type or what you will see. Never change a command to make it "look right". If the result is different from the page, that difference is the lesson.
