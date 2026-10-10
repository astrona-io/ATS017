# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.

## About this repo (ATS017 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** pass the **Platform Architecture and Infrastructure** domain
  of the **Certified Cloud Native Platform Engineer (CNPE)** exam. It is 15%
  of the exam.
- **What the exam really tests:** shaping a shared cluster by hand, on a live
  cluster, under time pressure. The exam has 15 to 20 hands-on tasks in two
  hours, done over `ssh <node>` with `kubectl`, `yq` and `curl`. The only
  documentation is `kubernetes.io/docs`, the Kubernetes blog and a short
  Quick Reference for the tool in each task. So the student must *do* things
  (set requests and limits, schedule pods onto the right nodes, write a
  NetworkPolicy, read an HPA's status, read a cost allocation, set a quota),
  and must know where each field lives in the API reference. Every
  explanation should lead to a command they can run, and every change should
  be proved by observed behaviour (a pod placed, a request blocked, a replica
  added, a pod rejected by quota).
- **Breadth over depth.** The CNPE covers many tools and asks for limited
  depth in each. Teach the one job the exam asks of a tool, its resource
  kinds, its status fields and its command-line output. Do not teach a tool's
  whole feature set.
- **The three exam competencies (curriculum items):**
  - Applying Platform Architecture Best Practices for Networking, Storage, and Compute
  - Using Cost Management Solutions for Right-Sizing and Scaling
  - Optimizing Multi-Tenancy Resource Usage

  The README table maps each section to its curriculum item.
- **The sections:** the order goes from one workload to many tenants: size
  and place one workload, connect it and give it storage, scale it to the
  load, see what it costs, then share the cluster fairly between teams.

  | Section | Title | Curriculum item |
  | --- | --- | --- |
  | 010 | Compute Placement And Sizing | Applying Platform Architecture Best Practices for Networking, Storage, and Compute |
  | 020 | Networking And Storage | Applying Platform Architecture Best Practices for Networking, Storage, and Compute |
  | 030 | Right-Sizing And Autoscaling | Using Cost Management Solutions for Right-Sizing and Scaling |
  | 040 | Cost Visibility With OpenCost | Using Cost Management Solutions for Right-Sizing and Scaling |
  | 050 | Multi-Tenancy Resources | Optimizing Multi-Tenancy Resource Usage |

- **Teach only the official CNPE tools.** The exam's tool list is Argo,
  Crossplane, Flagger, Flux, Gatekeeper, Grafana, Istio, Jaeger, Kyverno,
  Linkerd, OPA, OpenCost, OpenTelemetry, Prometheus and Tekton, plus built-in
  Kubernetes features (requests and limits, scheduling, Gateway API objects,
  NetworkPolicy, StorageClass, HPA, ResourceQuota, LimitRange, PriorityClass,
  in-place pod resize, `kubectl top`). Any other tool is plumbing: it may run
  in a playground, but a page names it in one sentence at most and never
  teaches it. In this course that means metrics-server (behind `kubectl top`
  and the HPA), the Gateway API controller from the astrona `gatewayAPI`
  addon, and the small Prometheus behind OpenCost. Right-sizing uses
  `kubectl top`, Prometheus queries and in-place pod resize, not the VPA.
- **The versions:** everything is built and checked on **Kubernetes 1.35**
  (the exam version, `kindest/node:v1.35.8`) with **kind v0.33.0**. Tool
  versions, pinned in each `prepare.sh` or `bootstrap/` script:

  | Tool | Version | Used in |
  | --- | --- | --- |
  | Kubernetes (`kindest/node`) | v1.35.8 | every section |
  | metrics-server | v0.9.0 | 010, 030, 040 |
  | Gateway API CRDs (installed by the astrona addon, experimental channel) | v1.6.1 | 020 |
  | Gateway API controller (astrona `gatewayAPI: envoy` addon, plumbing) | set by astrona | 020 |
  | OpenCost | 1.121.3 | 040 |
  | Prometheus (small chart; usage queries in 030, plumbing for OpenCost in 040) | pin at build | 030, 040 |
  | Helm | 4.3.0 | 020, 030, 040 (install only) |
  | podinfo | 6.15.0 | every section |
  | go-httpbin | 2.25.0 (image tag has no `v`) | every section |

  Do not teach fields, flags or output from other versions without saying so.
- **The main sources:** the Kubernetes documentation on
  <https://kubernetes.io/docs/>, the Gateway API site and the
  OpenCost documentation. Check every page against them. The exam itself:
  <https://training.linuxfoundation.org/certification/certified-cloud-native-platform-engineer-cnpe/>
  and the "Important Instructions: CNPE" page.

### Terms, not metaphors

Explanations use Kubernetes' and each tool's own words. Define each one in
plain technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| Request (resources) | The amount of CPU or memory the scheduler reserves for a container on a node |
| Limit | The most CPU or memory a container may use; over the memory limit the kernel kills it (`OOMKilled`), over the CPU limit it is throttled |
| QoS class | The class Kubernetes gives a pod from its requests and limits (`Guaranteed`, `Burstable`, `BestEffort`); it decides which pods the kubelet evicts first under node pressure |
| Node affinity | Pod rules that say which node labels a pod must have (`requiredDuringSchedulingIgnoredDuringExecution`) or should prefer |
| Pod anti-affinity | Pod rules that keep a pod away from nodes or zones that already run matching pods |
| Taint / toleration | A taint on a node repels pods; a toleration on a pod allows it onto a tainted node, but does not pull it there |
| Topology spread constraint | A pod rule that limits how uneven the number of matching pods may be across zones or nodes (`maxSkew`) |
| Gateway API | The Kubernetes API for traffic into the cluster: `GatewayClass`, `Gateway` (a listener) and `HTTPRoute` (routing rules) |
| NetworkPolicy | A namespaced object that selects pods and lists the ingress and egress traffic they allow; once a pod is selected, all other traffic in that direction is denied |
| StorageClass | Names a provisioner and its parameters; a PersistentVolumeClaim that names it gets a PersistentVolume created on demand (dynamic provisioning) |
| PersistentVolumeClaim (PVC) | A request for storage by size and access mode, bound to one PersistentVolume |
| HorizontalPodAutoscaler (HPA) | A controller that changes a workload's replica count to keep a metric (for example CPU utilisation of requests) near a target |
| In-place pod resize | Changing a running container's CPU and memory requests and limits through the pod's `resize` subresource, without recreating the pod |
| `resizePolicy` | Per-resource container field that says whether a resize needs a container restart (`NotRequired` or `RestartContainer`) |
| metrics-server | Collects CPU and memory usage from each kubelet and serves it to `kubectl top` and the HPA through the Metrics API |
| OpenCost | A CNCF tool that splits the cost of the cluster's nodes, storage and network across namespaces, controllers, pods and labels |
| Idle cost | Cost of node capacity that no pod requests or uses |
| ResourceQuota | A namespaced object that caps the total requests, limits and object counts of a namespace |
| LimitRange | A namespaced object that sets default, minimum and maximum requests and limits for each container in the namespace |
| PriorityClass | A cluster-wide object that gives pods a priority number; the scheduler can evict (preempt) lower-priority pods to place a higher-priority one |
| Quota scope | A filter that makes a ResourceQuota count only some pods (for example `PriorityClass`, `BestEffort`, `Terminating`) |

### The example workloads

Every section uses the same small Starfleet app. Its Kubernetes names come
from the space theme, so describe them in technical terms and use them as
they are.

| Kubernetes name | Image | What it is |
| --- | --- | --- |
| `starfleet` (namespace) | | The main team's namespace |
| `outpost` (namespace) | | A second tenant's namespace, used for isolation, quota and cost comparisons |
| `scout` (Deployment and Service) | `ghcr.io/stefanprodan/podinfo:6.15.0` | HTTP API on port `9898` with `/metrics`. It has no load endpoints; the start-up flags `--stress-cpu=<cores>` and `--stress-memory=<MB>` load it on purpose (checked on 6.15.0), used for throttling, `OOMKilled`, the HPA and right-sizing |
| `probe` (Deployment and Service) | `mccutchen/go-httpbin:2.25.0` | HTTP echo server on port `8080`, used as a second backend and as the target of NetworkPolicy tests |
| `shuttle` (Deployment) | `curlimages/curl` | Client pod; every test request is sent from here with `kubectl exec deploy/shuttle -- curl ...` |
| `bridge` (Deployment and Service) | `nginx` (pin at build) | Front end; only in modules that need one (Gateway API) |

The workloads use the `default` service account. Module playgrounds may
add a variant of a workload (for example a `scout` copy without requests,
or a `probe` in `outpost`) and must name it in the module.

### Environment facts the text must respect

- **Pin the cluster in `config.yaml`.** astrona's kind runtime takes
  `runtime.kind.image: kindest/node:v1.35.8` (or `runtime.kind.version`),
  `runtime.kind.nodes.workers`, `featureGates`, `runtimeConfig`,
  `preloadImages` and addons (`metricsServer`, `certManager`,
  `gatewayAPI: envoy`, `cni: calico`); see `astrona schema`. Prefer an addon
  over a hand-written install when it fits. It does not expose
  `kubeadmConfigPatches` or `extraMounts`.

Facts marked *(verify)* were not run on a cluster yet. Check them before a
page states them as fact, and remove the mark when checked.

- **One kind cluster per playground and lab.** Modules on scheduling,
  topology spread and preemption use a three-node kind cluster (one control
  plane, two workers) with `topology.kubernetes.io/zone` labels set in the
  kind configuration. Each extra node costs memory on the maintainer's
  machine; use one node when the subject does not need more.
- **No load balancer on `kind`.** A `LoadBalancer` Service keeps its
  external address `<pending>`. The astrona `gatewayAPI: envoy` addon
  configures Envoy Gateway to create a `ClusterIP` Service per Gateway, so a
  Gateway shows a cluster-internal address in `status.addresses` and
  `PROGRAMMED True` (checked). Send requests from `shuttle` to that address.
- **Gateway API needs a controller.** The CRDs alone do nothing. Playgrounds
  use the astrona `gatewayAPI: envoy` addon as plumbing. Pages teach the
  Gateway API objects and read the `GatewayClass` name from the cluster
  (`kubectl get gatewayclass`); they name the controller in one sentence at
  most. The addon installs the GatewayClass `eg` (Envoy Gateway) and the
  Gateway API CRDs **v1.6.1, experimental channel** (checked; not v1.6.3
  standard). ReferenceGrant is served as `v1` and `v1beta1`. The addon binds
  host ports 8080/8443 by default; set `addons.gatewayPorts` (18080/18443)
  because 8080 is often taken on the host.
- **kindnet enforces NetworkPolicy.** Since kind v0.24.0, kind's default CNI
  enforces NetworkPolicy through `kube-network-policies` (checked in the
  v0.24.0 release notes). No Calico or Cilium is needed. *(verify egress and
  `namespaceSelector` behaviour on kind v0.33.0 before writing output.)*
- **Default StorageClass.** kind ships a default StorageClass named
  `standard`, provisioner `rancher.io/local-path`, with
  `volumeBindingMode: WaitForFirstConsumer`, so a PVC stays `Pending` until a
  pod uses it (checked on `kindest/node:v1.35.8`: `standard (default)`,
  `rancher.io/local-path`, `Delete`, `WaitForFirstConsumer`, expansion
  `false`). Volumes are directories on the
  node; they support `ReadWriteOnce` only and do not resize.
- **metrics-server on kind** needs `--kubelet-insecure-tls`, because the
  kubelet serving certificates are self-signed. The astrona `metricsServer`
  addon installs v0.9.0 with that flag already set (checked). On a kind
  node, capacity equals allocatable (nothing reserved). The
  first `kubectl top` values appear about a minute after it starts; an HPA
  shows `<unknown>` until then.
- **In-place pod resize.** Kubernetes 1.35 can change a running container's
  requests and limits without recreating the pod, through the pod's
  `resize` subresource (`kubectl patch --subresource resize`) *(verify the
  feature state in 1.35 and the exact status fields and conditions)*. This
  is the right-sizing tool in section 030; the VPA is not taught.
- **OpenCost needs Prometheus.** OpenCost reads usage from Prometheus. Section
  040 installs a small Prometheus (not the full kube-prometheus-stack) and
  OpenCost with its default on-premises price list, because a kind cluster
  has no cloud billing. Costs on kind are therefore from that price list,
  not real bills; say so on the page. Cost data needs several minutes of
  samples before allocation shows non-zero values *(verify the wait)*.
- **Preemption needs a full node.** A preemption demonstration only works
  when the higher-priority pod cannot fit; playgrounds fill a worker with
  low-priority pods whose requests leave no room.
- **The proof is observed behaviour.** A change is proven with the matching
  command: the pod's `NODE` in `kubectl get pods -o wide`, a request from
  `shuttle` that succeeds or times out, `kubectl get hpa` showing the new
  replica count, `kubectl describe resourcequota` showing used against hard,
  or the `Forbidden` message from the API server when quota rejects a pod.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Curriculum design record (sections, modules, objectives, playground environments) | `.astrona/blueprint.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The exam-style task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough with real output |
| `bootstrap/` | Add-on installs (Prometheus, OpenCost) and the starting state; metrics-server and the Gateway API controller come from astrona addons |
| `manifests/` | `lab-start.yaml` (workloads) and any faulty configuration the learner must fix |
| `solution/apply.sh`, `solution/solution.yaml` | Reference end state, applied only by `astrona test` |
| `testing/` | Helpers `astrona test` runs |
| `validation/validate-*.sh` | Behavioural grading, one script per check |

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS017`, domain `Platform
Architecture and Infrastructure`, weight `15`) and one entry per section
under `modules:` (`module-intro`, `module-010`, `module-020` and so on).
Each section's `content` lists, in order: the section `README.md`, then for
each module its landing page, its parts, and right after the part a lab
tests, a `Question` reading (`labs/lab-01/question.md`) followed by the
`type: lab` entry; the module's closing page comes last. The section
capstone closes the section. Playgrounds are not listed: the landing page's
`<!-- astrona:playground -->` marker shows them.

Every `type: lab` entry (module labs and capstones) carries these fields, in
this order:

```yaml
      - type: reading
        title: Question
        path: sections/section-010/module-01/labs/lab-01/question.md
      - type: lab
        title: "Fix The Pending Pods Lab"
        path: sections/section-010/module-01/labs/lab-01
        difficulty: beginner
        estimated_duration: 15m
        topic: compute
        task_kind: troubleshooting
        tags: [requests-limits, qos-class, pending-pod, oomkilled]
        learning_goals:
          - Find why a pod stays Pending from its scheduler events
          - Set requests and limits that fit the node and give the pod the Burstable QoS class
          - Prove the fix with a Running pod and a 200 from the shuttle pod
        resources:
          - name: "Resource Management for Pods and Containers"
            url: https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
```

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `15m`, `30m`, `45m`.
- `topic`: exactly one of `compute`, `scheduling`, `networking`, `storage`,
  `autoscaling`, `cost`, `multi-tenancy`.
- `task_kind`: exactly one of `build` (write the configuration from
  scratch), `troubleshooting` (find and fix what is broken) or `migration`
  (move a working setup to another mode or layout). The platform filters
  labs by it, so it is a field of its own, never a tag.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb, saying
  what the learner proves in this lab.
- `resources`: 1 to 4 documentation pages, each with a `name` and a `url`
  that loads. Prefer `kubernetes.io` pages, because those are the pages the
  exam allows. This is the **only** place outside links are allowed: the
  platform shows them as optional further reading next to the lab.

**Tag list** (lower case, hyphens, never synonyms):

- Compute: `requests-limits`, `qos-class`, `oomkilled`, `cpu-throttling`,
  `pending-pod`, `eviction`
- Scheduling: `node-affinity`, `pod-anti-affinity`, `taints-tolerations`,
  `topology-spread`, `node-labels`, `preemption`
- Networking: `gateway-api`, `httproute`, `gateway`, `network-policy`,
  `default-deny`, `egress`, `dns`
- Storage: `storageclass`, `pvc`, `dynamic-provisioning`,
  `volume-binding-mode`, `reclaim-policy`, `access-modes`
- Autoscaling: `hpa`, `metrics-server`, `scaling-behavior`,
  `in-place-resize`, `usage-vs-requests`, `right-sizing`
- Cost: `opencost`, `cost-allocation`, `idle-cost`, `cost-labels`,
  `prometheus`
- Multi-tenancy: `resourcequota`, `limitrange`, `priorityclass`,
  `quota-scopes`, `namespace-isolation`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-010/module-01/playground
astrona destroy ats-017-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS017.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-017-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-017-playground-<section>-<module>`, a module lab
is `ats-017-lab-<section>-<module>` and a capstone is
`ats-017-capstone-<section>`; keep those names. A second lab in a module
takes `ats-017-lab-<section>-<module>-<lab>`, for example
`ats-017-lab-020-02-02`, so two labs never share a name. Lab bootstrap
scripts do not pin a kube context: astrona sets `KUBECONFIG` for the lab, and
`astrona test` runs on a cluster with a different name. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists: send a real
request from `shuttle`, check the node a pod landed on, read the HPA's
replica count, or create a pod and expect quota to reject it. Many graders
also reject the plausible but wrong fix (deleting the NetworkPolicy instead
of allowing the one flow, removing the taint instead of adding a toleration,
raising the quota instead of setting a LimitRange default). A lab's
`question.md` and `solution.md` must match what its `validation/` scripts
actually check.

Test clusters on the maintainer's machine: one at a time. Podman has 10 GiB
and also runs the platform stack; parallel clusters run it out of memory.
The three-node clusters and section 040 (Prometheus and OpenCost) are the
heaviest. Never touch clusters you did not create.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory, and
prefer `kubernetes.io` pages, because those are the pages a candidate can
open during the exam.

- **Compute and scheduling:**
  [resource management for pods and containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/),
  [pod quality of service classes](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/),
  [assigning pods to nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/),
  [taints and tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/),
  [pod topology spread constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/),
  [resize CPU and memory in place](https://kubernetes.io/docs/tasks/configure-pod-container/resize-container-resources/)
- **Networking and storage:**
  [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/),
  [Gateway API site](https://gateway-api.sigs.k8s.io/),
  [network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/),
  [storage classes](https://kubernetes.io/docs/concepts/storage/storage-classes/),
  [dynamic volume provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/),
  [persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- **Scaling and right-sizing:**
  [horizontal pod autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/),
  [HPA walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/),
  [metrics-server](https://github.com/kubernetes-sigs/metrics-server)
- **Cost:**
  [OpenCost documentation](https://opencost.io/docs/),
  [OpenCost installation](https://opencost.io/docs/installation/install),
  [OpenCost API](https://opencost.io/docs/integrations/api)
- **Multi-tenancy:**
  [resource quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/),
  [limit ranges](https://kubernetes.io/docs/concepts/policy/limit-range/),
  [pod priority and preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/),
  [multi-tenancy](https://kubernetes.io/docs/concepts/security/multi-tenancy/)
- **The exam itself:** the CNPE page on the Linux Foundation training site
  lists the official curriculum, and the "Important Instructions: CNPE" page
  lists the exam environment and the featured tools. The domain weight (15%)
  and the three competencies above were checked against the CNPE page on
  2026-10-10.

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository: planning
(`domain-plan`), creating the tree (`domain-scaffold`), building modules
(`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds (`lab`),
lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
