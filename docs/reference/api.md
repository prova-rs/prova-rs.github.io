---
sidebar_position: 2.5
sidebar_label: "API Index"
---

# API Index

Every function, method and type the `prova` binary reports, with its signature and summary.
This page is generated from `prova introspect` by `scripts/reference_from_introspect.py`;
do not edit it by hand. The module pages ([Modules](./modules/index.md)) and the
[Lua API](./lua-api/index.md) explain the important ones in depth, and
[Verifiers & Measurements](./modules/verifiers.md) covers the deputed-evidence namespaces.
The stubs this page is generated from are held to the runtime by prova's own tests.

Generated for prova v0.30.13 (`prova introspect` in your own shell always
matches the binary you run).

## Namespaces

### `archetect`

```lua
archetect.render(opts: prova.RenderOpts) -> prova.RenderResult
```

Render an archetype in-process and return its output tree.

```lua
archetect.verify(spec: prova.VerifySpec) -> prova.Fixture
```

Register the standard layout/fully-rendered/yaml/build checks against a rendering, returning the render fixture so you can hang boot/probe fixtures and extra tests off the same output. Two forms over one core — the compositional form makes render → verify → black-box one pipeline: archetect.verify&#123; source = ..., &lt;checks> &#125; -- one-shot: renders for you archetect.verify(project_fixture, &#123; &lt;checks> &#125;) -- checks a render fixture you declared

### `base64`

```lua
base64.decode(s: string) -> string
```

Decode base64 text to the original bytes. Raises on invalid input.

```lua
base64.encode(s: string) -> string
```

Base64-encode a string (standard alphabet, padded). Binary-safe.

### `csv`

```lua
csv.decode(s: string, opts?: prova.CsvOpts) -> table<string, string>[]
```

Parse CSV text, header-aware: the first record names the columns, every remaining record becomes a map keyed by header (the `prova.parse.table` row shape; values stay strings).

```lua
csv.encode(rows: table<string, any>[], opts?: prova.CsvOpts) -> string
```

Encode a list of header-keyed row maps as CSV text with a header line. Quoting is automatic (RFC 4180).

### `date`

```lua
date.days_since(v: string|integer) -> integer
```

Whole days from `v` until now, floored.

```lua
date.days_until(v: string|integer) -> integer
```

Whole days from now until `v`, floored.

```lua
date.diff_days(a: string|integer, b: string|integer) -> integer
```

Whole days from `a` to `b`, floored.

```lua
date.format(ts?: integer, fmt?: string) -> string
```

`os.date` formatting, "%Y-%m-%d" by default.

```lua
date.now() -> integer
```

The current time, unix seconds.

```lua
date.parse(s: string) -> integer
```

Unix seconds for a date string.

```lua
date.past(v: string|integer) -> boolean
```

True once `v` is in the past.

### `docker`

```lua
docker.build(opts: prova.DockerBuildOpts) -> string image
```

Build a local image from a Dockerfile and return its ref, ready for `docker.run&#123; image = … &#125;`. Honors `.dockerignore`, BuildKit cache mounts, and BuildKit secrets. Raises with the builder's log if the build fails. A production Dockerfile that reads a private registry token via `RUN --mount=type=secret,id=npm` is built by naming that id in `secrets`: `secrets = &#123; npm = &#123; env = "NPM_TOKEN" &#125; &#125;`. Prefer this over `buildargs` for anything sensitive — build args are recorded in image history, which is what BuildKit secrets exist to avoid.

```lua
docker.diagnostics() -> { port_bind_recoveries: integer, port_bind_failures: integer }
```

What the container runtime got wrong that prova papered over: recoveries are silent, and a silent recovery is indistinguishable from nothing having gone wrong. Process-wide and monotonic, so read it before and after and take the delta (a soak comparing runtimes).

```lua
docker.network(opts?: prova.DockerNetworkOpts) -> prova.Network
```

Create a user-defined bridge network (embedded DNS). Manage it with `ctx:manage`.

```lua
docker.run(opts: prova.DockerRunOpts) -> prova.Container
```

Start a container (detached, `--rm`) and return a handle once it is ready. The image is pulled only if it is not already local (`docker run`'s own rule), so a locally-built image works.

### `fs`

```lua
fs.digest(paths: string|string[]) -> string digest
```

A stable lowercase-hex digest over the CONTENTS and paths of the files matching `paths` (a path or glob, or a list of them) — the primitive behind conduct identity (`prova learn fixtures`). Sorted and `/`-separated, so the same tree answers identically on every OS and in whatever order you list it. A path matching nothing contributes its ABSENCE rather than raising: absence changes a build, so it changes the digest.

```lua
fs.exists(path: string) -> boolean
```

Whether a file or directory exists.

```lua
fs.glob(root: string, pattern: string) -> string[] absolute paths
```

Every path under `root` matching a glob `pattern` (`*` within a segment, `**` across segments). Returns **ABSOLUTE**, `/`-normalized paths, not paths relative to `root` — strip `root` yourself if you need relative ones (a report keyed on absolute paths differs per machine). Directories are matched too, so pattern for what you want (`"**/*.rs"`, not `"**"`). Order is unspecified — sort it.

```lua
fs.mkdir(path: string)
```

Create a directory and every missing parent (like `mkdir -p`); idempotent (no error if it already exists). The platform-agnostic replacement for `shell.run("mkdir -p ...")`.

```lua
fs.read(path: string) -> string
```

Read a whole file as a string. Raises if it does not exist — check `fs.exists` first when absence is a normal outcome rather than a bug.

```lua
fs.remove_all(path: string)
```

Delete a path and everything under it. No error if it is already gone.

```lua
fs.tempdir() -> string path
```

Create a temp dir with NO scope to clean it up — the escape hatch for code that has no context to ask. Inside a test or fixture prefer `ctx:tempdir(name)`, which is reaped with the scope and gives you as many directories as you have names. Not auto-cleaned; pair with `ctx:defer`. The returned path is absolute and `/`-normalized on every OS (no `\`, no `\\?\` prefix — safe to embed in TOML, shell strings, and patterns).

```lua
fs.write(path: string, contents: string)
```

Write `contents` to `path`, creating parent directories as needed.

### `graphql`

```lua
graphql.client(opts: prova.GraphqlClientOpts) -> prova.GraphqlClient
```

Build a GraphQL client for one endpoint.

### `grpc`

```lua
grpc.client(addr: string, opts?: prova.GrpcClientOpts) -> prova.GrpcClient
```

A client for the gRPC server at `addr` (`"host:port"`, `"http://host:port"` or, over TLS, `"https://host:port"`), performing reflection once to discover its services. Must be called inside a fixture or test body (async). Three ways to say TLS, all equivalent: an `https://` address, `tls = true` on a bare `"host:port"`, or `insecure`/`ca_cert` (which imply it). An `http://` address with any of them is a contradiction and raises (architecture.md#tls-everywhere).

```lua
grpc.mock(ctx: prova.Context|prova.TestContext, opts: prova.GrpcMockOpts) -> prova.GrpcMock
```

Provision a mock gRPC server, tied to `ctx`'s scope. Unlike `grpc.client`, a mock **must be told its schema**: the client needs no `.proto` because it learns one *from the server* by reflection, and a mock is the server — there is nobody to learn from. Hence `proto`. Reach for it on the boundary you cannot run, for status codes the real service won't produce on demand, or to assert on the **interaction itself**. If you can run the real service, run it.

```lua
grpc.proxy(ctx: prova.Context|prova.TestContext, opts: prova.GrpcProxyOpts) -> prova.GrpcMock
```

Interpose on a real gRPC dependency (docs/design/mocks-proxies-drivers.md). Record captures the upstream's schema (learned by reflection) AND each unary call into a cassette, so a replay proxy needs no `.proto` and no upstream — the cassette is self-describing. The match key is the full method plus the request message; a replay miss is a loud `Unavailable` naming the cassette. Same object as `grpc.mock` — its `:received()` journal and `:on` stubs apply. Close (or scope exit) is the flush point. Returns a mock (dial the SUT's gRPC client at `.host`/`.port`).

```lua
grpc.wait_for(addr: string, opts?: prova.GrpcWaitOpts)
```

Poll until the server answers a reflection request or the timeout elapses (boot-then-probe).

### `hash`

```lua
hash.hmac_sha256(key: string, msg: string) -> string
```

HMAC-SHA-256 of `msg` keyed by `key`, as lowercase hex.

```lua
hash.sha256(s: string) -> string
```

SHA-256 digest as lowercase hex.

### `http`

```lua
http.client(opts: prova.HttpClientOpts) -> prova.HttpClient
```

Build a reusable REST client bound to a base URL and default headers.

```lua
http.delete(url: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a DELETE. Does **not** raise on 4xx/5xx — assert on `res.status`.

```lua
http.get(url: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a GET. Does **not** raise on 4xx/5xx — assert on `res.status` yourself; only a transport failure (DNS, refused, timeout) raises.

```lua
http.head(url: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a HEAD — status + headers, no body. Cheap liveness/existence check.

```lua
http.mock(ctx: prova.Context|prova.TestContext, opts?: prova.MockOpts) -> prova.MockServer
```

Provision a mock HTTP server, tied to `ctx`'s scope. The fourth facet: `client` attaches to a real dependency, `container` provisions a real one, `wait_for` probes one — `mock` provisions a **fake** one. For a **stateful fake**, close over a table in your fixture and mutate it from a `:reply` handler (it is real Lua); assert on that table directly. Reach for a mock on the boundary you cannot run, for behavior the real thing won't produce on demand, or to assert on the interaction itself — if you *can* run the real thing, run it (`prova.containerized`). The listener is bound before this returns, so the first request cannot race it — no `prova.retry` needed. See `examples/ordering_test.lua` for a worked stateful fake.

```lua
http.options(url: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue an OPTIONS — the allowed methods/CORS preflight for a resource.

```lua
http.patch(url: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a PATCH. Does **not** raise on 4xx/5xx — assert on `res.status`.

```lua
http.post(url: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a POST. Name the body with exactly one of `opts.json`/`opts.form`/`opts.body` — two is an error, not a precedence. Does **not** raise on 4xx/5xx — assert on `res.status`.

```lua
http.proxy(ctx: any, opts: prova.HttpProxyOpts) -> prova.MockServer
```

Interpose on a real HTTP dependency: forward traffic, record it into a cassette, or replay a cassette with the upstream gone ("a proxy in record mode manufactures a mock"). Sugar over `http.mock`'s dial — same object back, so stubs/journal/faults all apply. `mode = "auto"` records when the cassette file is absent and replays when present; a replay miss is a loud 502 naming the cassette. Close (or scope exit) is the cassette flush point.

```lua
http.put(url: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a PUT. Does **not** raise on 4xx/5xx — assert on `res.status`.

```lua
http.wait_for(url: string, opts?: prova.WaitOpts) -> prova.HttpResponse
```

Poll until the endpoint responds as expected or the timeout elapses.

### `json`

```lua
json.array(t: table) -> table
```

Mark a table as an array for encoding (forces `[]` when empty). Returns the same table.

```lua
json.decode(s: string) -> any
```

Parse JSON into a Lua value. `null` decodes to `nil` — top-level or nested — so absent and null both read as nil (assert explicit null with `json.null` in a `:matches` shape instead).

```lua
json.encode(v: any, opts?: prova.JsonEncodeOpts) -> string
```

Encode a Lua value as JSON text (compact by default). A bare empty table encodes as an object (`&#123;&#125;`); wrap it in `json.array` to force `[]`; `json.null` emits an explicit null.

### `junit`

```lua
junit.ingest(report: prova.JunitReport) -> integer
```

File a loaded report's cases into the run's deputed account (what `verify` calls after loading; a no-op outside a recorded run, so querying with `load` never pollutes anything).

```lua
junit.load(pattern: string, opts?: prova.JunitLoadOpts) -> prova.JunitReport
```

Parse JUnit XML result files (a path or glob) into a structured report — the primitive. Tolerant of dialect drift; consumes the stable core (names, outcomes, messages, timings).

```lua
junit.merge(prior: string, rerun?: string, opts: { reused_from: string, out: string }) -> string
```

A deputy's full account after a resumed run re-ran only its failures: every case of `prior` the rerun did not re-run is carried forward and MARKED with the run it came from; a re-run case replaces its prior verdict. A re-run pass over a prior red is `flaky`, never a pass. Writes the merged XML to `opts.out` and returns that path.

```lua
junit.select(path: string, opts: { suites: string[], out: string }) -> integer
```

The part of one account whose suites are named: a suite `s` takes `s` itself and every `s::…` (nextest names a binary `&lt;package>::&lt;binary>`), so one batched conduct splits into per-module accounts. Every case keeps its verdict and origin. Writes to `opts.out`.

```lua
junit.union(paths: string[], opts: { out: string }) -> string
```

Disjoint accounts made one: the slices of one partitioned conduct (`nextest --partition`). A case in two of them is REFUSED — slices never overlap, so a duplicate is a broken partition, never a re-run (that is `merge`). Writes to `opts.out`.

```lua
junit.verify(t: prova.TestContext, opts: prova.JunitVerifyOpts) -> prova.JunitReport
```

The verifier facet: run the deputy (optional), load its FRESH results, ingest them, and adopt the verdict — any failed/errored case fails the proof with the deputed cases' own names and messages, and zero parsed cases fails too (a glob matching nothing must never read as green). Returns the report. ```lua prova.test("the service's own suite holds", &#123; tags = &#123; "unit" &#125; &#125;, function(t) junit.verify(t, &#123; run = "mvn -q test", results = "target/surefire-reports/*.xml" &#125;) end) ```

### `measure`

```lua
measure.ratchet(t: prova.TestContext, name: string, value: number, opts?: prova.MeasureOpts)
```

Record `value` and assert it against the committed baseline: red on a regression past the floor (and its `tolerance`), on a missing baseline, on a reached `goal`, and on a missed `deadline`. Only `prova --update-baseline` moves a baseline, and only tighter.

```lua
measure.record(name: string, value: number, opts?: prova.MeasureOpts) -> number
```

File `value` into the run's measurements without asserting (a no-op outside a run).

### `net`

```lua
net.free_port() -> integer
```

An OS-assigned free TCP port on 127.0.0.1 — for a locally `shell.spawn`ed app that needs a dynamic port (a container gets its random host port from `docker.run` instead).

### `prova`

```lua
prova.archetect{}
```

```lua
prova.barrier(token: string, parties: integer, opts?: prova.BarrierOpts) -> integer position
```

Wait until `parties` participants have arrived at `token`, then release them together. The concurrency assertion: reaching the far side IS the proof the participants were in flight at once, so there is no window to have been lucky in. `prova.sleep` measures timing luck in both directions — it fails on a loaded host and passes when a serialized system happens to overlap. Bounded: `timeout` defaults to 30s and reaching it FAILS the test, naming how many of how many arrived. Participants become one atomic selection unit — `-k`, `--node` and `--last-failed` that pick some of them leave the rest waiting — so reach for it when concurrency is the property under proof, not as a general coordination tool.

```lua
prova.base64{}
```

```lua
prova.cargo{}
```

```lua
prova.containerized(spec: prova.ContainerizedSpec) -> { client?: fun(url: string, opts: table): any, container: fun(ctx: prova.Context, opts?: table): prova.ContainerResource }
```

Build a grammar-conformant resource namespace (`&#123; client?, container &#125;`) from a compact spec — the scaffolding every containerized recipe/plugin is authored through, so first-party and third-party resources come out the same shape (the tier-agnostic interface). The generated `container(ctx, opts?)` provisions via docker, waits, ties teardown to the scope, and returns a `prova.ContainerResource`, attaching a managed `client` only when the spec provides a `client` factory. `opts.network` (a `docker.network()` handle or name) + `opts.alias` join the resource to a topology network and populate `resource.network` — how a containerized SUT reaches it. The same recipe expresses the **system under test**: give it `build` instead of `image` and the image is built from the project's own Dockerfile rather than pulled. A SUT is not a separate concept — it is a resource whose image is local, so it inherits the topology auto-join, the network vantage, readiness and teardown unchanged, and the suite needs only Docker (no host SDK).

```lua
prova.csv{}
```

```lua
prova.date{}
```

```lua
prova.describe(label: string, body: fun())
```

Group tests for reporting. Labeling-only in v1 (does not introduce a new fixture scope).

```lua
prova.docker{}
```

```lua
prova.fixture(name: string, scope: prova.ScopeRef, factory: fun(ctx: prova.Context): T, opts?: prova.FixtureOpts) -> prova.Fixture<T>
```

Declare a fixture: a named factory producing a value, with scoped teardown and dependencies. `scope` is a `Scope` value (`Scope.Test`/`Scope.Flow`/`Scope.File`/`Scope.Suite`/`Scope.Run`); omit it for `Scope.Test`. Returns a typed handle; pass it to `ctx:use(handle)` so the value type flows through. `Scope.Run` values must be plain data (JSON-serializable): the one conduct crosses Lua states, so each reader gets its own copy and `ctx:defer` is unavailable in the factory.

```lua
prova.flow(name: string, opts: prova.FlowOpts, body: fun(flow: prova.FlowBuilder)) -> prova.Flow
```

Declare a flow: an ordered sequence of steps sharing the flow's scope. Steps run in order on one worker; once a step fails, the rest are skipped. The go-to construct when you need ordering plus built-up state. Returns a handle usable in `depends_on`.

```lua
prova.fs{}
```

```lua
prova.graphql{}
```

```lua
prova.group(name: string, opts: prova.GroupOpts, body: fun(g: prova.GroupBuilder)) -> prova.Group
```

Declare an independent group: an isolated, unordered, parallelizable bag of child units. The builder exposes `test`/`flow`/`group` but **no shared-state mechanism** — that is the point (invalid states unrepresentable). Returns a handle usable in `depends_on`.

```lua
prova.grpc{}
```

```lua
prova.hash{}
```

```lua
prova.help(filter?: string) -> { name: string, signature: string, summary: string }[]
```

The API surface, as data — every function, method, and value shape as `&#123; name, signature, summary &#125;`. `filter` narrows by case-insensitive substring across name and summary. Ask this instead of guessing: `prova.help("shell")`, `prova.help("ShellResult")`. Parsed from these same stubs, so it cannot drift from what your editor completes.

```lua
prova.http{}
```

```lua
prova.infra(msg: string)
```

Fail this node for a cause in the environment, not the code under proof: a build tool that cannot read the workspace, a toolchain that cannot run. The node is `failed` as ever, and its JSON event also says `cause = "infra"` with `msg`'s first line as `cause_line`, so a gate can tell an infra red from a real one by value. Herald gives no verdict for it and rides again. The cause is the error's TYPE, never its text: a proof's own `error()` that quotes infra's words is a plain red. A proof that catches this error with `pcall` and re-raises the SAME value (`error(e, 0)`) still says infra, deliberately: it passes the cause on. Re-raising its text (`error(tostring(e))`) does not.

```lua
prova.json{ null: lightuserdata  -- explicit-null sentinel: emit null from encode, assert null in shapes }
```

```lua
prova.junit{}
```

```lua
prova.measure{}
```

```lua
prova.net{}
```

```lua
prova.parse{}
```

The exec-CLI output-parsing toolkit: turn the text a container CLI returns into Lua values.

```lua
prova.path{}
```

String-based on purpose (NOT the OS path type, which renders `\` on Windows): every function accepts either separator and emits `/`-normalized strings, so the same proof assertions hold on every OS. No filesystem access — pure string laws.

```lua
prova.port(number: integer) -> prova.ResourceRef
```

A typed **exclusive** resource for a TCP port — a listener is a writer of its port. Preferred over `"port:8080"`: validates the number and can't be mistyped into an unrelated token.

```lua
prova.reads(resource: prova.ResourceRef|string) -> prova.ResourceRef
```

A **reader** hold on a resource — concurrent: readers of the same token run together, and a writer waits for all of them to release before it starts. Accepts a bare token or an existing ref, so `prova.reads(prova.port(5432))` widens a port to a shared hold.

```lua
prova.remind(name: string, opts: prova.RemindOpts, message: string)
```

Declare a **reminder** — an obligation the world creates (the attention account, not the evidence account). Not a test: it never enters the tally, the selection, or burndown. The condition evaluates after the proofs complete; while it returns falsy the reminder is WATCHING (armed and observing — silence in the run output), and when it returns truthy the reminder is DUE — attention owed, reported in the run, `prova reminders`, and `prova owed`. The message is the instruction: what to DO when it fires, because a reminder is discharged by an act, not an assertion. A due reminder never fails the run by default (the world moving is not a defect in the change under test); a lane that promises attention opts in with `heed_reminders = true` in prova.toml (or `--heed` for one invocation). ```lua prova.remind("stay current with prova-redis", &#123; when = function(account) local latest = releases.latest("prova-rs/prova-redis") return semver.gt(latest, "v1") and (latest .. " is out; we pin v1") end, &#125;, "integrate the new release and bump [dependencies]") ```

```lua
prova.report{}
```

```lua
prova.retry(fn: fun(): T, opts?: prova.RetryOpts) -> T
```

Call `fn` repeatedly until it returns a truthy value (a raised error counts as "not ready"), or the deadline elapses. Returns the value. The readiness primitive — replaces the hand-rolled `for _=1,N do pcall(...) sleep end` loop: `local conn = prova.retry(function() return sqlite.client(url) end)`.

```lua
prova.runtime{}
```

`runtime.*` — the Lua-shaped configuration DSL for the whole runtime. Available ONLY in the optional `prova.lua` companion beside `prova.toml`; calling it from a test raises (it configures the environment tests run *in*, and only the companion loads early enough to do that).

```lua
prova.sarif{}
```

```lua
prova.shell{}
```

```lua
prova.sleep(millis: integer)
```

Await `millis` milliseconds without blocking the worker (cooperative async). A low-level timing primitive, mainly for tests and boot-then-probe waits; prefer `http.wait_for` for readiness polls.

```lua
prova.socket{}
```

```lua
prova.sqlite{}
```

```lua
prova.stdio{}
```

```lua
prova.str{}
```

The casing half CALLS archetect's own inflections and MIRRORS archetect's filter names (`constant_case` is archetect's name for screaming-snake, so it is prova's too) — one implementation, one vocabulary, so a proof asserting on an archetype's rendered output uses the very function the archetype's templates did.

```lua
prova.suite{}
```

Configure the current suite — call in a `suite.lua` file (a directory's `suite.lua` groups its `*_test.lua` into one suite that shares a Lua state, so `Scope.Suite` fixtures are built once and shared across the files). Test files reference the suite's fixtures by name, e.g. `t:use("db")`.

```lua
prova.terminal{}
```

```lua
prova.test(name: string, opts: prova.TestOpts, factory: fun(t: prova.TestContext)) -> prova.Test
```

Declare an independent test in the file's implicit group. Returns a handle for `depends_on`.

```lua
prova.test_each(name_template: string, cases: table[], factory: fun(t: prova.TestContext, case: table)) -> prova.Test[]
```

Declare a table-driven test: one test per case. `&#123;placeholder&#125;`s in `name_template` are filled from each case table; the case reaches the body as its second argument and as `t.case`. Returns the list of generated test handles (any usable in `depends_on`).

```lua
prova.toml{}
```

```lua
prova.topology(name: string, scope: prova.ScopeRef, factory: fun(ctx: prova.Context): T) -> prova.Fixture<T>
```

Declare a **topology**: a named, verb-agnostic bundle of wired resources. It is a fixture (default `Scope.File` — provisioned once, shared across a file's tests) that is *also* addressable by name: `prova up &lt;name>` and `prova start &lt;name>` stand up the identical object outside any test, printing each resource's `url`. In test mode use it exactly like any fixture — `t:use(handle)`. One definition powers both your tests and your dev environment, so they cannot drift.

```lua
prova.url{}
```

```lua
prova.uuid{}
```

```lua
prova.websocket{}
```

```lua
prova.workspace{}
```

The `prova.workspace` module: `create` is the whole surface.

```lua
prova.writes(resource: prova.ResourceRef|string) -> prova.ResourceRef
```

A **writer** hold on a resource — exclusive: while this unit runs, nothing else may hold that token, reader or writer. Name what the test does to the resource (`prova.writes("db")` for a migration) and the scheduler derives the rest. Accepts a bare token or an existing ref.

```lua
prova.yaml{}
```

### `prova.cargo`

```lua
prova.cargo.account(t: prova.TestContext, name?: string) -> string
```

The account of module `name` (default: this proof's module) — a junit path, for `junit.load` readers that bind claims to named cases.

```lua
prova.cargo.configure(opts: prova.CargoConfigureOpts)
```

Set the conduct's nextest profile, junit file name and extra arguments, once, where the package's proofs share setup: every state that may conduct must agree, since whichever asks first conducts for the run.

```lua
prova.cargo.verify(t: prova.TestContext, opts?: { module?: string }) -> prova.JunitReport
```

Adopt a module's account: every case ingested, red on any failed one, red on an empty one. A leaf that may conduct holds the cargo lock: `locks = &#123; prova.writes("cargo") &#125;`. ```lua local cargo = require("prova.cargo") prova.test("billing's unit cases pass", &#123; locks = &#123; prova.writes("cargo") &#125; &#125;, function(t) cargo.verify(t) end) ```

### `prova.parse`

```lua
prova.parse.lines(s: string) -> string[]
```

Split into non-empty, trimmed lines.

```lua
prova.parse.rows(s: string, sep?: string) -> string[][]
```

Split each non-empty line on `sep` (default tab) into a list of columns.

```lua
prova.parse.table(s: string, sep?: string) -> table<string, string>[]
```

Treat the first non-empty line as a header row; return each remaining row as a map keyed by header.

### `prova.path`

```lua
prova.path.basename(p: string) -> string
```

The last component (`""` for a bare root, which has none).

```lua
prova.path.dirname(p: string) -> string
```

Everything before the last component — `"."` for a bare name, the root for a first-level entry (`"/a"` → `"/"`, `"C:/a"` → `"C:/"`). A trailing slash does not make a component.

```lua
prova.path.ext(p: string) -> string
```

The extension of the last component WITHOUT the dot (`"txt"`, not `".txt"`); `""` when there is none. A dotfile (`".gitignore"`) is all stem, no extension.

```lua
prova.path.is_absolute(p: string) -> boolean
```

Whether `p` is absolute — unix (`"/…"`), drive (`"C:/…"` or `"C:\…"`), or UNC (`"//server/…"`).

```lua
prova.path.join(...: string) -> string
```

Join segments with `/`; empty segments contribute nothing, and an absolute later segment resets the join (`path.join("a", "/etc", "b")` → `"/etc/b"`).

```lua
prova.path.normalize(p: string) -> string
```

Collapse `.`/`..`/duplicate separators, strip any trailing slash, emit `/`. Purely lexical: leading `..` in a relative path survives; `..` cannot climb above a root; `""` → `"."`.

```lua
prova.path.stem(p: string) -> string
```

The last component minus its extension (`"b.tar.gz"` → `"b.tar"`).

### `prova.str`

```lua
prova.str.camel_case(s: string) -> string
```

`helloWorld` (archetect's `camel_case` filter)

```lua
prova.str.class_case(s: string) -> string
```

`FooBar`, singularized (`"foo_bars"` → `"FooBar"`) — archetect's `class_case`

```lua
prova.str.cobol_case(s: string) -> string
```

`HELLO-WORLD` (archetect's `cobol_case`)

```lua
prova.str.constant_case(s: string) -> string
```

`HELLO_WORLD` — archetect's name for screaming-snake

```lua
prova.str.deordinalize(s: string) -> string
```

`"1st"` → `"1"` (archetect's `deordinalize`)

```lua
prova.str.directory_case(s: string) -> string
```

`foo/bar` (archetect's `directory_case`)

```lua
prova.str.is_camel_case(s: string) -> boolean
```

Whether `s` is already camelCase.

```lua
prova.str.is_class_case(s: string) -> boolean
```

Whether `s` is already ClassCase (pascal, singular).

```lua
prova.str.is_cobol_case(s: string) -> boolean
```

Whether `s` is already COBOL-CASE.

```lua
prova.str.is_constant_case(s: string) -> boolean
```

Whether `s` is already CONSTANT_CASE.

```lua
prova.str.is_directory_case(s: string) -> boolean
```

Whether `s` is already directory/case.

```lua
prova.str.is_kebab_case(s: string) -> boolean
```

Whether `s` is already kebab-case.

```lua
prova.str.is_package_case(s: string) -> boolean
```

Whether `s` is already package.case.

```lua
prova.str.is_pascal_case(s: string) -> boolean
```

Whether `s` is already PascalCase.

```lua
prova.str.is_sentence_case(s: string) -> boolean
```

Whether `s` is already Sentence case.

```lua
prova.str.is_snake_case(s: string) -> boolean
```

Whether `s` is already snake_case.

```lua
prova.str.is_title_case(s: string) -> boolean
```

Whether `s` is already Title Case.

```lua
prova.str.is_train_case(s: string) -> boolean
```

Whether `s` is already Train-Case.

```lua
prova.str.kebab_case(s: string) -> string
```

`hello-world` (archetect's `kebab_case`)

```lua
prova.str.lines(s: string) -> string[]
```

The portable line reader: split on `\n`, absorbing a preceding `\r`; a trailing newline yields no phantom empty line. Same result whether the text came from a unix or a Windows program.

```lua
prova.str.ordinalize(s: string) -> string
```

`"1"` → `"1st"`, `"22"` → `"22nd"` (archetect's `ordinalize`)

```lua
prova.str.package_case(s: string) -> string
```

`foo.bar` (archetect's `package_case`)

```lua
prova.str.pascal_case(s: string) -> string
```

`HelloWorld` (archetect's `pascal_case`)

```lua
prova.str.pluralize(s: string) -> string
```

`"user"` → `"users"` (archetect's `pluralize`)

```lua
prova.str.sentence_case(s: string) -> string
```

`Hello world` (archetect's `sentence_case`)

```lua
prova.str.singularize(s: string) -> string
```

`"users"` → `"user"` (archetect's `singularize`)

```lua
prova.str.snake_case(s: string) -> string
```

`hello_world` (archetect's `snake_case`)

```lua
prova.str.split(s: string, sep: string) -> string[]
```

Split on a plain (non-pattern) separator, KEEPING empty fields — `"a,,c"` has three fields. The separator must be non-empty.

```lua
prova.str.title_case(s: string) -> string
```

`Hello World` (archetect's `title_case`)

```lua
prova.str.train_case(s: string) -> string
```

`Hello-World` (archetect's `train_case`)

```lua
prova.str.trim(s: string) -> string
```

Strip surrounding whitespace from both ends.

### `prova.workspace`

```lua
prova.workspace.create(ctx: prova.Context, opts?: table) -> prova.Workspace
```

Create a scratch directory whose lifetime is tied to `ctx` — removed on scope teardown.

### `report`

```lua
report.publish(opts: prova.ReportOpts)
```

Publish an artifact this conduct produced, and take custody of it (docs/design/verifiers.md#reports-are-custody-not-visualization). The third thing a deputed conduct hands back, beside cases (which the ledger adopts) and measurements (which the ratchets hold). The file is COPIED into `.prova/var/reports/&lt;name>/` immediately, because `target/` is swept and a fixture's tempdir is reaped — a recorded path that rots is worse than no report, since it reads as available. Prova never renders the artifact; the deputy already did. Prova preserves it, summarizes it in one line, and makes it addressable (`prova reports`, and the run record for agents). ```lua report.publish&#123; name = "coverage", summary = "unit 73.47% · merged 86.37%", explains = "rust.coverage.unit", forms = &#123; json = json_path, html = html_dir .. "/index.html" &#125;, &#125; ```

### `runtime`

```lua
runtime.capability(name: string, predicate: fun(): boolean|string|nil)
```

DEPRECATED — declare capabilities in `prova.toml`'s `[capabilities]` instead: [capabilities] gpu = &#123; package = "env", capability = "gpu" &#125; and move this predicate into that package as an exported `capabilities.gpu` function, where a proof can call it directly. The companion file, this function, the `runtime` global, `[run] config`, `--config`, and `PROVA_CONFIG` retire together (docs/design/deprecations.md#retire-capability-companion). Registers a project-wide capability — a fact about what THIS system, as configured, can test: its OS, hardware, and software. A property of the environment, not the code. The name (not the closure) is what lets a skip say what was missing; the predicate is only how it is detected. The name works in both directions: `requires = &#123; "gpu" &#125;` (skip if unmet) and `must_run = ["gpu"]` (fail if unmet). See docs/design/capabilities.md.

### `sarif`

```lua
sarif.ingest(report: prova.SarifReport)
```

File a loaded report's findings into the run's deputed account (a no-op outside a run).

```lua
sarif.load(pattern: string, opts?: { cwd?: string }) -> prova.SarifReport
```

Parse SARIF files (a path or glob) into a report without recording anything.

```lua
sarif.verify(t: prova.TestContext, opts: prova.SarifVerifyOpts) -> prova.SarifReport
```

Conduct a linter and adopt its verdict: run it tolerantly, load and ingest its FRESH SARIF, and fail when more than `max` findings sit at or above `level`. Unlike junit, zero findings is a clean pass. ```lua sarif.verify(t, &#123; run = "npx eslint . -f @microsoft/eslint-formatter-sarif -o e.sarif", results = "e.sarif", level = "warning" &#125;) ```

### `shell`

```lua
shell.proxy(ctx: any, opts: prova.ShellProxyOpts) -> prova.ShellShim
```

Shadow a command NAME on PATH and interpose on every invocation the SUT makes: pass through to `upstream` and journal (spy), stub selected argv prefixes (stubs always win), or — with no upstream — terminate synthetically, where an unstubbed call fails LOUD (exit 127). Shadow the name the SUT execs, never a shell builtin (`sh` answers those itself, PATH unconsulted). With a `cassette` + `mode` it records a real CLI once and replays it forever: `record` captures argv+stdin → stdout+exit (flushed at `:stop()`, into a file OUTSIDE the shim dir), `replay` answers from the recording with no upstream and no real binary, `auto` records-then-replays. A replay miss exits non-zero and is journaled as a miss.

```lua
shell.run(command: string|string[], opts?: prova.ShellOpts) -> prova.ShellResult
```

Run a command to completion. A **string** goes through a shell, so `"cargo build --release"` works verbatim. An **argv table** (`&#123;"psql", "-tAc", sql&#125;`) runs the program directly — no shell, no quoting — which is how you pass content (SQL, source, JSON, paths with spaces) safely.

```lua
shell.spawn(command: string|string[], opts?: prova.SpawnOpts) -> prova.Process
```

Start a long-running command in the background (a booted app, a mock server) and return a handle. stdout and stderr are captured — read the last 64KB of them with `proc:output()`, which is how you diagnose a service that booted and then died. Pair with `ctx:manage(proc)` (or `ctx:defer(function() proc:stop() end)`) so it stops at scope end. Takes a shell string or an **argv table** (no shell, no quoting), exactly like `shell.run` — there is no `args` option, because the arguments are part of the command.

### `socket`

```lua
socket.connect(ctx: any, opts: prova.SocketConnectOpts) -> prova.SocketConn
```

Connect (originate): dial a `tcp://`/`unix://` address. Async. Closed with the scope.

```lua
socket.listen(ctx: any, opts: prova.SocketListenOpts) -> prova.SocketListener
```

Listen (originate, server side): bind `tcp://host:port` (`:0` = ephemeral, resolved into `.addr`) or `unix:///path`, accept raw or framed connections. Torn down with the scope.

```lua
socket.mock(ctx: any, opts: prova.SocketMockOpts) -> prova.SocketMock
```

Terminate: a mock that answers framed turns synthetically. Framing is REQUIRED — matching needs turns; raw exchanges are scripted with `socket.listen`/`accept` instead.

```lua
socket.proxy(ctx: any, opts: prova.SocketProxyOpts) -> prova.SocketProxy
```

Interpose: the universal wiretap. Put it in front of ANY tcp/unix dependency for transcripts and fault injection (latency/drop/corrupt/throttle/after) with zero protocol knowledge. With a `cassette` + `mode` it becomes a framed-turn recorder: `record` captures request→response turns (flushed on `:close()`), `replay` answers from the cassette with the upstream gone, `auto` records when the file is absent and replays when present. A replay miss severs the connection loud. Cassettes require `framing` (a raw byte stream has no turn to key on).

### `sqlite`

```lua
sqlite.client(url: string) -> prova.Connection
```

Open a SQLite database by URL (`sqlite://&lt;path>?mode=rwc`, or `sqlite::memory:`). Nothing to provision — there is no `sqlite.container`.

### `stdio`

```lua
stdio.mock(ctx: any, opts: prova.StdioMockOpts) -> prova.StdioMock
```

Terminate: shadow a command NAME on PATH with a framed responder the SUT SPAWNS. This is `socket.mock` reached by spawn instead of dial — the shim on PATH is two lines (`exec &lt;prova> relay --to unix://…`) and carries no behavior, so stubs, journal and matching stay in-process. That is what lets `:on` take a SHAPE; a shim that was itself the matcher could only ever match bytes.

```lua
stdio.proxy(ctx: any, opts: prova.StdioProxyOpts) -> prova.StdioProxy
```

Interpose: shadow a command NAME, spawn the REAL server behind it, and pair every request with its response — the turn-by-turn session wiretap `shell.proxy` cannot be (its turn is one whole invocation, so a conversation collapses into a single blob). With `cassette` + `mode` it records a real session once and replays it credential-free forever: `record` captures pairs (flushed on `:close()`), `replay` answers with no upstream at all, `auto` records when the file is absent and replays when present. A replay miss ends the session loud. The recording is byte-turn shaped — the same format `socket.proxy` writes, and portable between them.

```lua
stdio.spawn(ctx: any, opts: prova.StdioSpawnOpts) -> prova.Session
```

Drive (originate): spawn a program with its stdin, stdout and stderr piped, and converse. Takes a shell string or an argv table, exactly like `shell.run` — there is no `args` option, because the arguments are part of the command. `framing` turns the byte stream into turns (`"line"` is newline-delimited JSON, as MCP over stdio speaks; `"content_length"` is the LSP/DAP envelope) and `codec = "json"` decodes them, so `recv&#123; where = &#123; id = 3 &#125; &#125;` picks the reply out of an interleaved stream.

### `suite`

```lua
suite.config(config: prova.SuiteConfig)
```

Declare this suite's configuration (see `prova.SuiteConfig`). Call once, at the top of a file.

### `terminal`

```lua
terminal.mock(ctx: any, opts: prova.TerminalMockOpts) -> prova.TerminalMock
```

Shadow an interactive CLI on PATH with a scripted responder — the SUT shells out to `ssh` (or an installer), and you script the other side.

```lua
terminal.proxy(ctx: any, opts: prova.TerminalProxyOpts) -> prova.TerminalProxy
```

Interpose on an interactive CLI the SUT shells out to (the last cell in the transport matrix): shadow a command NAME on PATH, forward to the REAL program on the pty the SUT already allocated, and record the session — or replay a recorded one with no real program. The terminal cassette is the full-duplex, asciinema-shaped kind: the raw terminal stream with VT sequences intact, so a session recorded once (a ConPTY session on Windows) replays deterministically on every platform. Modes: passthrough (default) \| record \| replay \| auto.

```lua
terminal.spawn(ctx: any, opts: prova.TerminalSpawnOpts) -> prova.Term
```

Spawn a program on a real pty (openpty/ConPTY behind one API) and drive it interactively.

### `toml`

```lua
toml.decode(s: string) -> table
```

Parse TOML text into a Lua value. Raises on invalid TOML.

```lua
toml.encode(v: table) -> string
```

Encode a table as TOML text. TOML has no null, so `json.null` is an encode error here.

### `url`

```lua
url.decode(s: string) -> string
```

Decode percent-encoding — `encode`'s exact inverse. A COMPONENT codec, so `+` stays a literal plus (form encoding reads it as a space; the two differ on exactly that character). Returns bytes: a percent sequence can carry any octet, so nothing is lost to a UTF-8 conversion.

```lua
url.encode(s: string) -> string
```

Percent-encode a string as one URL component: everything but RFC 3986 unreserved characters is escaped (space → `%20`, not `+`).

```lua
url.parse(s: string) -> prova.UrlParts
```

Parse a URL into its structured parts. Raises on an invalid URL.

### `uuid`

```lua
uuid.v4() -> string
```

A random (v4) RFC 4122 UUID, hyphenated lowercase.

### `websocket`

```lua
websocket.connect(ctx: any, opts: prova.WebsocketConnectOpts) -> prova.WsConn
```

Connect (originate): dial a `ws://` or `wss://` url. Async. Closed with the scope. `insecure`/`ca_cert` mean exactly what they mean on `http` — one policy, one spelling (architecture.md#tls-everywhere).

```lua
websocket.mock(ctx: any, opts?: prova.WebsocketMockOpts) -> prova.WsMock
```

Terminate (and push): a real ws server in this process, stubbed and asserted on.

```lua
websocket.proxy(ctx: any, opts: prova.WebsocketProxyOpts) -> prova.WsProxy
```

Interpose on a real ws dependency: forward message turns, record a direction-tagged transcript, and apply the fault vocabulary (the last cell in the transport matrix). `insecure`/`ca_cert` apply to the UPSTREAM leg (which may be `wss://`). The tap itself always listens plaintext on loopback: a proxy exists to be read, and terminating TLS on the side your proof connects to would mean generating a certificate for a hop that never leaves the machine.

### `yaml`

```lua
yaml.decode(text: string) -> any
```

Parse a single YAML document into a Lua value. Raises on invalid YAML.

```lua
yaml.decode_all(text: string) -> any[]
```

Parse a multi-document YAML stream (`---`-separated, as in Kubernetes manifests) into a list of Lua values. Raises on the first invalid document.

```lua
yaml.encode(v: any) -> string
```

Emit one value as a YAML document. Carries the json sentinels: `json.null` emits an explicit null; `json.array&#123;&#125;` forces an empty sequence.

```lua
yaml.encode_all(docs: any[]) -> string
```

Emit a list of values as one `---`-separated multi-document stream (the Kubernetes manifest shape) — the exact inverse of `yaml.decode_all`.

## Types and methods

### `479 entries in the core API surface`

```lua
479 entries in the core API surface
```

### `BarrierOpts`

```lua
prova.BarrierOpts{ timeout?: string  -- how long to wait for every party (default "30s"); reaching it FAILS the test }
```

### `CargoConfigureOpts`

```lua
prova.CargoConfigureOpts{ profile?: string  -- the nextest profile; its junit must be enabled (default "default"), junit?: string  -- that profile's junit file name, under <target>/nextest/<profile>/, args?: string[]  -- extra `cargo nextest run` arguments (features, --test-threads, …), run?: table  -- extra `shell.run` options for the conduct: `env`, `sample`, `idle_timeout` }
```

### `ConductIdentity`

```lua
prova.ConductIdentity{ command: string  -- the conduct's command line — the question it answers, inputs: string[]  -- package-relative paths or globs whose contents change the answer }
```

What a run-scoped conduct IS, so two differently-named fixtures asking the same question share one execution: the command it runs and the files its answer depends on (`fs.digest` keys it).

### `Connection`

```lua
Connection:close()
```

Close the connection pool.

```lua
Connection:execute(sql: string, params?: any[]) -> integer
```

Run a statement (INSERT/UPDATE/DDL); returns the number of rows affected.

```lua
Connection:query(sql: string, params?: any[]) -> table<string, any>[]
```

Run a query; returns a list of rows, each a table of column name -> value (NULL -> nil).

```lua
Connection:query_value(sql: string, params?: any[]) -> any
```

Query returning a single scalar (first column of the first row), or nil.

```lua
prova.Connection{}
```

A database connection from `sqlite.client`. Methods are async; pair with `ctx:manage(conn)` to close it on teardown. Use `?` placeholders in SQL.

### `Container`

```lua
Container:endpoint(container_port: integer) -> string
```

Convenience: "127.0.0.1:&lt;host_port>" for a published container port.

```lua
Container:exec(command: string) -> integer, string, string
```

Run a command inside the container (`sh -c`); returns (code, stdout, stderr). Low-level and non-raising — prefer `Container:run` for driving a CLI.

```lua
Container:host_port(container_port: integer) -> integer
```

The host port a published container port maps to.

```lua
Container:logs() -> string
```

The container's combined stdout+stderr logs.

```lua
Container:network_alias() -> string|nil
```

The alias this container answers to on its user-defined network (from `docker.run`'s `alias`), or nil if it joined no network or joined one without an alias. Siblings resolve it by DNS.

```lua
Container:run(command: string|string[], opts?: { stdin?: string }) -> string stdout
```

Run a command inside the container and return its stdout, raising on a non-zero exit. The exec-CLI SDK entry point: pass an **argv table** to run a CLI directly (no shell, no quoting), or a **string** to run under `sh -c` (for pipes/globs). `opts.stdin` is piped to the process.

```lua
Container:stop()
```

Force-remove the container. Idempotent.

```lua
prova.Container{ id: string }
```

A running container from `docker.run`. Prefer `ctx:defer(function() c:stop() end)` so it is removed during teardown; `stop`/`logs`/`exec` are async.

### `ContainerResource`

```lua
prova.ContainerResource{ url: string  -- host-vantage connection URL (127.0.0.1:mapped_port), host: string  -- "127.0.0.1", port: integer  -- the mapped host port, container: any  -- the docker Container handle, client?: any  -- the attached client (when the spec provides one), network?: prova.NetworkVantage  -- present when provisioned on a network (opts.network + opts.alias) }
```

The standard resource shape a containerized recipe/plugin returns.

### `ContainerizedSpec`

```lua
prova.ContainerizedSpec{ name?: string  -- namespace name, for error messages, image?: string  -- base image repo (e.g. "redis") — PULLED; `opts.image` fully overrides. Mutually exclusive with `build`, build?: string|prova.DockerBuildOpts  -- BUILT from a Dockerfile (the system under test) — a string is shorthand for `{ context = … }`. Mutually exclusive with `image`, tag?: string  -- default tag for a pulled `image`; `opts.tag` overrides, port?: integer  -- primary published port (readiness + url); or use `ports`, ports?: integer|(integer|{ container: integer, host: integer })[]  -- ports to publish; a `{container,host}` entry fixes the host port, command?: string  -- optional container command, env?: table<string,string>|fun(opts: table): table<string,string>  -- container env (may read opts), wait?: { port?: integer, log?: string }  -- readiness probe (default: primary port), timeout?: string  -- readiness deadline (default "60s"), url: fun(host_port: integer, opts: table): string  -- connection URL from the mapped host port, client?: fun(url: string, opts: table, container: any): any  -- attach a client (native uses url; docker-exec uses container); omit for black-box, extra?: fun(url: string, opts: table, container: any): table  -- additional resource fields beyond the trio (e.g. s3 credentials) }
```

### `Context`

```lua
Context:defer(fn: fun())
```

Register a teardown callback for the current scope. Callbacks run LIFO when the scope ends; a fixture's deferrals run before those of any fixture it depended on.

```lua
Context:log(msg: string)
```

Attach a structured log line to the current test/fixture in the report.

```lua
Context:manage(resource: T) -> T
```

Tie a resource's lifecycle to the current scope: on teardown, call its `stop()` (containers, processes) or `close()` (connections). Returns the resource, so it composes inline: `local pg = ctx:manage(docker.run&#123;...&#125;)`. Sugar over `defer` — use `defer` for custom teardown.

```lua
Context:tempdir(name?: string) -> string path
```

This scope's scratch directory, addressed by name. `ctx:tempdir()` is the unnamed one; `ctx:tempdir("plugin")` is a second, `ctx:tempdir("consumer")` a third. Same name, same directory, every time — so a write and a later read always meet. All of them are removed when the scope ends, and the name appears in the directory's own path, so a failed run's scratch tree says which is which. The returned path is absolute and `/`-normalized on every OS (no `\`, no `\\?\` prefix).

```lua
Context:use(fixture: prova.Fixture<T>) -> T
```

Instantiate or fetch a fixture value. Lazy: the fixture is built on first use and then cached for its scope. Fixture-to-fixture dependencies use this too. Prefer passing the **handle** returned by `prova.fixture` — the fixture's value type then flows through to the call site (full completion + type-checking). Passing a bare string name also works (cross-file lookup) but yields an untyped `any`.

```lua
prova.Context{ network?: prova.Network  -- the topology's managed network — non-nil ONLY inside a `prova.topology` factory; resources provisioned there via `prova.containerized` auto-join it, aliased by name. Nil in ordinary fixtures and test bodies. }
```

Base context passed to fixture factories.

### `CsvOpts`

```lua
prova.CsvOpts{ delimiter?: string  -- single-byte field delimiter (default ","), headers?: string[]  -- encode only: column order (default: first row's keys, sorted) }
```

### `DirHandle`

```lua
prova.DirHandle{ path: string }
```

A directory handle.

### `DockerBuildOpts`

```lua
prova.DockerBuildOpts{ context: string  -- the build-context directory, dockerfile?: string  -- relative to `context` (default "Dockerfile"); `COPY` still resolves against the context root, tag?: string  -- default: a stable tag derived from `context`, so rebuilds replace it and the layer cache hits, buildargs?: table<string,string|number|boolean>, secrets?: table<string, prova.DockerBuildSecret>  -- BuildKit secrets by id, for `RUN --mount=type=secret,id=…`. Exactly one of env/file/value per secret, target?: string  -- multi-stage build target, pull?: boolean  -- always re-pull the base image (default false), nocache?: boolean  -- ignore the build cache (default false), first_byte?: string  -- how long the builder may say NOTHING before it is called wedged (default "90s"; "0s" disables) — BuildKit prints `load build definition` within seconds when healthy, so this catches a wedged buildkitd in seconds instead of at the suite's bound }
```

### `DockerBuildSecret`

```lua
prova.DockerBuildSecret{ env?: string  -- read the secret from this variable in prova's own environment, file?: string  -- a file already on disk (must exist), value?: string  -- a literal value; written to a 0600 temp file for the build and removed after }
```

### `DockerFile`

```lua
prova.DockerFile{ text?: string  -- a literal, written verbatim, file?: string  -- a file already on disk, copied (keeps its own mode), dir?: string  -- a directory, copied recursively, mode?: string  -- octal, e.g. "0755" — for something the container executes }
```

### `DockerNetworkOpts`

```lua
prova.DockerNetworkOpts{ name?: string  -- override the generated unique "prova-net-<...>" name }
```

### `DockerRunOpts`

```lua
prova.DockerRunOpts{ image: string, command?: string|string[]  -- override the image CMD ("bin/pulsar standalone" or a list), ports?: (integer|{container:integer, host:integer})[]  -- container ports → random host ports (or a fixed host port), env?: table<string,string>, wait?: prova.DockerWait  -- readiness gate, network?: prova.Network|string  -- a user-defined network to join at create time (handle or name), alias?: string  -- DNS alias to answer to on `network` (requires `network`), extra_hosts?: string[]  -- `"name:ip"` entries added to the container's /etc/hosts, e.g. "host.docker.internal:host-gateway" (Linux) to reach a host-bound mock, files?: table<string, prova.DockerFile>  -- content carried INTO the container between create and start, keyed by ABSOLUTE container path — config needs no image build. Not a bind mount: the bytes travel the daemon API, so it works against a remote or rootless daemon }
```

### `DockerWait`

```lua
prova.DockerWait{ port?: integer  -- ready when this container port is in LISTEN state (asks the container, not the host), log?: string  -- ready when the logs contain this substring, cmd?: string[]  -- ready when this command, run in the container, exits 0 (e.g. {"pg_isready","-U","postgres"}), timeout?: string  -- default "30s", every?: string  -- poll interval, default "250ms" }
```

Readiness gate. Give exactly ONE signal — `port`, `log`, or `cmd` — each honest about a different observable. Use `port` when a listening socket means serving (Redis, nginx); use `cmd` when it does not (Postgres binds TCP then finishes startup — `pg_isready` is the race-free check).

### `Double`

```lua
Double.new(opts?: prova.DoubleOpts) -> prova.Double
```

Create a double (alias for calling the module directly).

```lua
Double:call(input: any) -> any reply
```

Dispatch one call: record it (with a monotonic `seq`), then answer it — a stub, else a proxy `target`, else raise (a mock's unpredicted call is a finding). `d(input)` is sugar for this.

```lua
Double:on(match: table|fun(input: any): boolean|nil) -> prova.DoubleStub
```

Register a stub; chain `:reply(…)` onto the returned handle. First matching stub wins, in declaration order. `match` is a SUBSET table (each field must deep-equal in the input), a predicate function, or nil (matches every call).

```lua
Double:received(filter?: table|fun(input: any): boolean) -> prova.DoubleCall[]
```

Every call the double saw, IN ORDER, as data: `&#123; seq, input, reply, matched, source &#125;` where `source` is "stub" \| "target" \| "unmatched". `filter` narrows over the recorded `input` the same way `:on` matches — so you assert on a subset, and on ordering, with the ordinary matchers.

```lua
Double:reset()
```

Discard the recorded calls (not the stubs), to assert on a test's phases in isolation.

```lua
prova.Double{}
```

A programmable double. Callable — `d(input)` is `d:call(input)` — so it drops in where a real function went. The module itself is the constructor: `require("prova.double")(opts?)` (or its `.new(opts?)` alias) returns one.

### `DoubleCall`

```lua
prova.DoubleCall{ seq: integer  -- 1-based position in the log — monotonic, so ordering is assertable, input: any  -- the argument the double was called with, reply: any  -- what it answered (absent for an unmatched call), matched: boolean  -- whether a stub matched, source: string  -- "stub" | "target" (proxied) | "unmatched" }
```

One recorded call. A handler's argument and a journal row are the same shape.

### `DoubleOpts`

```lua
prova.DoubleOpts{ target?: fun(input: any): any, label?: string }
```

Options for a double. `target` makes it a PROXY (unstubbed calls pass through to it and are logged; stubs still win); omit it for a MOCK (an unstubbed call raises). `label` names the double in that error.

### `DoubleStub`

```lua
DoubleStub:reply(reply: any|fun(input: any): any) -> prova.DoubleStub
```

Answer matching calls with `reply` — a value, or a `function(input)` computing one. The function is real Lua, run when the call arrives, so it computes from the input and closes over test locals.

```lua
prova.DoubleStub{}
```

A stub handle from `Double:on`. `:reply(…)` sets its answer.

### `ExpectOpts`

```lua
prova.ExpectOpts{ timeout?: string }
```

Options for `expect` on a stdio session.

### `FileHandle`

```lua
FileHandle:read() -> string contents
```

Read this file's contents as a string.

```lua
prova.FileHandle{ path: string  -- absolute path }
```

A file handle rooted within a tree. Read its contents, or assert on it via `expect`.

### `Fixture`

```lua
prova.Fixture<T>{}
```

A fixture handle returned by `prova.fixture`. Generic over the fixture's value type `T`, so `ctx:use(handle)` recovers `T` at the call site. Treat it as opaque — pass it to `use`, don't inspect it.

### `FixtureOpts`

```lua
prova.FixtureOpts{ identity?: prova.ConductIdentity  -- `Scope.Run` only: two fixtures with the same identity are ONE conduct }
```

A fixture's options. Scope is a `Scope` value, not an option. (Parametrized fixtures were considered and deliberately dropped — parametrization stays explicit: `test_each` for data-driven tests, separate suites for divergent variants, profiles for env.)

### `Flow`

```lua
prova.Flow{}
```

A flow handle returned by `prova.flow`. One ordered scheduling unit.

### `FlowBuilder`

```lua
FlowBuilder:step(name: string, body: fun(t: prova.TestContext))
```

Declare an ordered step. Steps run in declaration order on a single worker. Fixtures are used *inside* a step via `t:use(...)`, like everywhere else — a flow-scoped fixture is scope-cached, so `t:use(f)` returns the same instance across the flow's steps. (There is deliberately no `flow:use` builder sugar; see docs/plans/phase1-ergonomics.md.)

```lua
prova.FlowBuilder{}
```

The flow builder: the *sequence* strategy. Declares ordered steps that share the flow's scope; later steps are skipped once an earlier one fails. Shared mutable state lives here and only here — this is the sole capability that grants it.

### `FlowOpts`

```lua
prova.FlowOpts{ promises?: string  -- an open flow — see prova.TestOpts.promises, proves?: string  -- a kept flow's context — see prova.TestOpts.proves }
```

### `GraphqlClient`

```lua
GraphqlClient:execute(query: string, variables?: table) -> prova.GraphqlResult
```

Like `query`, but never raises: returns `&#123; data, errors, status &#125;` so a test can assert on GraphQL errors (mirrors grpc's `call_status`). `data`/`errors` are nil when absent/null.

```lua
GraphqlClient:query(query: string, variables?: table) -> any data
```

Run a query/mutation and return its `data`. Raises if the response carries GraphQL `errors`.

```lua
prova.GraphqlClient{}
```

A GraphQL client bound to one endpoint (queries and mutations share the transport).

### `GraphqlClientOpts`

```lua
prova.GraphqlClientOpts{ url: string, headers?: table<string,string>, timeout?: string, insecure?: boolean  -- accept any certificate — no chain, hostname or expiry check. The supported way to probe a service you just booted with a self-signed cert; the handshake is still encrypted, only identity goes unchecked. Mutually exclusive with `ca_cert`., ca_cert?: string  -- PEM file whose certificates are ADDED to the default trust anchors (Mozilla's bundle + the platform store) — for an endpoint behind a private CA. Mutually exclusive with `insecure`. }
```

### `GraphqlResult`

```lua
prova.GraphqlResult{ status: integer, data?: any, errors?: table[] }
```

### `Group`

```lua
prova.Group{}
```

A group handle returned by `prova.group`. One scheduling unit whose children run per the group's independent strategy.

### `GroupBuilder`

```lua
GroupBuilder:describe(label: string, body: fun(g: prova.GroupBuilder))
```

Label-only subgrouping for reporting (inherits strategy; no new scope).

```lua
GroupBuilder:flow(name: string, opts: prova.FlowOpts, body: fun(flow: prova.FlowBuilder)) -> prova.Flow
```

Declare a flow (ordered sequence) as a child unit of this group.

```lua
GroupBuilder:group(name: string, opts: prova.GroupOpts, body: fun(g: prova.GroupBuilder)) -> prova.Group
```

Declare a nested group.

```lua
GroupBuilder:test(name: string, opts: prova.TestOpts, factory: fun(t: prova.TestContext)) -> prova.Test
```

Declare an independent test in this group.

```lua
GroupBuilder:test_each(name_template: string, cases: table[], factory: fun(t: prova.TestContext, case: table)) -> prova.Test[]
```

Table-driven tests within this group: one test per case, names filled from `&#123;placeholder&#125;`s.

```lua
prova.GroupBuilder{}
```

The group builder: the *independent* strategy. Declares child units (tests, flows, nested groups) that are isolated and parallelizable. It deliberately exposes **no shared-state mechanism** — cross-child built-up context is not representable here; use a `flow`.

### `GroupOpts`

```lua
prova.GroupOpts{}
```

A group is the *independent* strategy: children are isolated, unordered, parallelizable. It carries only the shared options; `promises`/`proves` are refused on a group (flag each test).

### `GrpcClient`

```lua
GrpcClient:call(method: string, request?: table) -> table response
```

Invoke a unary method (`"package.Service/Method"`), raising on a non-OK gRPC status.

```lua
GrpcClient:call_status(method: string, request?: table) -> prova.GrpcStatus
```

Like `call`, but never raises: returns `&#123; ok, code, message, response &#125;` so a test can assert on the gRPC status code (e.g. `"NotFound"`, `"InvalidArgument"`). `response` is nil unless `ok`.

```lua
prova.GrpcClient{}
```

A connected gRPC client from `grpc.client`. It learned the server's schema at connect time via gRPC Server Reflection, so calls take a plain request table and return a response table — no generated code. Methods are async; the server must have reflection enabled. Plaintext-only in v1.

### `GrpcClientOpts`

```lua
prova.GrpcClientOpts{ timeout?: string  -- per-call deadline, e.g. "30s", tls?: boolean  -- ask for TLS on a bare `"host:port"` — the only way to request VERIFIED TLS without writing a scheme. Unnecessary with an `https://` address, or when `insecure`/`ca_cert` already imply TLS., insecure?: boolean  -- accept any certificate — no chain, hostname or expiry check. The supported way to probe a service you just booted with a self-signed cert; the handshake is still encrypted, only identity goes unchecked. Mutually exclusive with `ca_cert`., ca_cert?: string  -- PEM file whose certificates are ADDED to the default trust anchors (Mozilla's bundle + the platform store) — for an endpoint behind a private CA. Mutually exclusive with `insecure`. }
```

### `GrpcMock`

```lua
GrpcMock:after(delay: string) -> prova.GrpcMock
```

(grpc.proxy) Schedule a fault: `p:after("100ms"):drop()` — healthy first, injured later.

```lua
GrpcMock:close()
```

Alias for `:stop()` — the proxy grammar's teardown verb.

```lua
GrpcMock:drop()
```

(grpc.proxy) Sever — subsequent calls fail with `Unavailable`.

```lua
GrpcMock:latency(duration: string)
```

(grpc.proxy) Continuous latency on every call, both directions ("2s"). The transport-generic fault verb; byte-level corrupt/throttle stay socket-only.

```lua
GrpcMock:on(match: prova.GrpcMockMatch) -> prova.GrpcMockStub
```

Register a canned response for a method on this mock server.

```lua
GrpcMock:received(filter?: { method?: string }) -> prova.GrpcMockCall[]
```

Every RPC the mock was asked, in order — as data, for the ordinary matchers. Unstubbed calls are recorded too (they answer `Unimplemented`): a call you did not predict is usually the most interesting thing a mock can tell you.

```lua
GrpcMock:stop()
```

Stop serving. Idempotent — the owning scope calls this too. In a `grpc.proxy` record mode, the cassette flush point.

```lua
prova.GrpcMock{ url: string  -- "http://127.0.0.1:<port>", host: string  -- "127.0.0.1", port: integer  -- the bound port (random, so parallel tests don't collide), endpoint: string  -- the driver-target alias == "host:port" (what grpc.client takes), network?: { url: string, host: string, port: integer }  -- cross-substrate vantage; present only with `network` }
```

A mock gRPC server: a real server, in this process. It **serves reflection**, so `grpc.client` drives it with no special case — and `m.url` wires into a system under test exactly as a real service's would.

### `GrpcMockCall`

```lua
prova.GrpcMockCall{ method: string  -- "package.Service/Method", request: any  -- the decoded request message, as a table, code?: string  -- journal only: the status the mock answered ("Ok", "NotFound", …), matched?: boolean  -- journal only: whether any stub matched, error?: string  -- journal only: why a handler failed, if it did }
```

An RPC as the mock saw it. A handler's argument and a journal entry are the **same shape**.

### `GrpcMockMatch`

```lua
prova.GrpcMockMatch{ method?: string  -- exact: "package.Service/Method", method_matches?: string  -- a Lua pattern (the same dialect as `:matches(pat)`) }
```

Which RPCs a stub answers. Omitted fields don't constrain. **First matching stub wins**, in declaration order.

### `GrpcMockOpts`

```lua
prova.GrpcMockOpts{ proto: string|string[]  -- `.proto` path(s), compiled at runtime (pure Rust; no protoc), includes?: string[]  -- import paths (default: each proto's own directory), allow_handler_errors?: boolean  -- a raising `:reply` handler normally FAILS the owning scope at, network?: boolean|string  -- expose a `.network` host-gateway vantage (binds 0.0.0.0); see http.mock }
```

### `GrpcMockReply`

```lua
prova.GrpcMockReply{ response?: any  -- the reply message, as a table (default: an empty message), code?: string  -- "NotFound", "ResourceExhausted", … (default "Ok"), message?: string  -- the status message, for a non-Ok code, delay?: string  -- hold the reply this long ("250ms") — fault injection }
```

What a stub answers: a `response` message, or a non-Ok `code` — not both, because an RPC returns a message or a status. `code` uses the spelling `client:call_status` **reports**, so what a failure tells you is what you write to reproduce it.

### `GrpcMockStub`

```lua
GrpcMockStub:reply(reply: prova.GrpcMockReply|fun(call: prova.GrpcMockCall): prova.GrpcMockReply)
```

Answer matching RPCs with `reply` — a table, or a **function** taking the call and returning one. The function is real Lua, run at request time on this Lua state while the coroutine driving the system under test is suspended, so it can compute from the request and close over test locals.

```lua
prova.GrpcMockStub{}
```

### `GrpcProxyOpts`

```lua
prova.GrpcProxyOpts{ upstream?: string  -- the real gRPC server (host:port), needed by passthrough/record/auto, cassette?: string  -- the recording file, needed by record/replay/auto, mode?: string  -- "passthrough" (default) | "record" | "replay" | "auto", redact?: string[]  -- literal strings scrubbed from the cassette at record time, network?: boolean|string  -- a `.network` host-gateway vantage for a containerized SUT; see http.mock }
```

### `GrpcStatus`

```lua
prova.GrpcStatus{ ok: boolean, code: string  -- gRPC status code name, e.g. "Ok" | "NotFound" | "InvalidArgument", message: string, response?: table }
```

### `GrpcWaitOpts`

```lua
prova.GrpcWaitOpts{ timeout?: string  -- overall deadline (default "30s"), every?: string  -- poll interval (default "500ms"), tls?: boolean  -- as on `grpc.client`, insecure?: boolean  -- accept any certificate — no chain, hostname or expiry check. The supported way to probe a service you just booted with a self-signed cert; the handshake is still encrypted, only identity goes unchecked. Mutually exclusive with `ca_cert`., ca_cert?: string  -- PEM file whose certificates are ADDED to the default trust anchors (Mozilla's bundle + the platform store) — for an endpoint behind a private CA. Mutually exclusive with `insecure`. }
```

### `HttpClient`

```lua
HttpClient:delete(path: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a DELETE against this client's base URL. Does **not** raise on 4xx/5xx.

```lua
HttpClient:get(path: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a GET against this client's base URL. Does **not** raise on 4xx/5xx — assert on `res.status`.

```lua
HttpClient:head(path: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a HEAD against this client's base URL — status + headers, no body.

```lua
HttpClient:options(path: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue an OPTIONS against this client's base URL.

```lua
HttpClient:patch(path: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a PATCH against this client's base URL. Does **not** raise on 4xx/5xx.

```lua
HttpClient:post(path: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a POST against this client's base URL. Does **not** raise on 4xx/5xx.

```lua
HttpClient:put(path: string, opts?: prova.HttpOpts) -> prova.HttpResponse
```

Issue a PUT against this client's base URL. Does **not** raise on 4xx/5xx.

```lua
HttpClient:wait_for(path: string, opts?: prova.WaitOpts) -> prova.HttpResponse
```

Poll a path until it answers as expected (readiness). Retries the real request rather than sleeping.

```lua
prova.HttpClient{}
```

A reusable REST client: base URL + default headers declared once. `path` is joined onto `base_url` (an absolute URL is used verbatim); per-call `opts` override the defaults.

### `HttpClientOpts`

```lua
prova.HttpClientOpts{ base_url: string  -- prefixed onto each call's path, headers?: table<string,string>  -- default headers (per-call headers override by name), timeout?: string  -- default per-call timeout, insecure?: boolean  -- accept any certificate — no chain, hostname or expiry check. The supported way to probe a service you just booted with a self-signed cert; the handshake is still encrypted, only identity goes unchecked. Mutually exclusive with `ca_cert`., ca_cert?: string  -- PEM file whose certificates are ADDED to the default trust anchors (Mozilla's bundle + the platform store) — for an endpoint behind a private CA. Mutually exclusive with `insecure`. }
```

### `HttpOpts`

```lua
prova.HttpOpts{ headers?: table<string,string>, json?: table  -- request body, JSON-encoded, form?: table  -- request body, application/x-www-form-urlencoded (scalar fields), body?: string  -- request body, sent verbatim (bytes), content_type?: string  -- media type; overrides the one `json`/`form` imply, timeout?: string, redirects?: boolean|integer  -- false = return the 3xx; N = follow at most N; default follows, insecure?: boolean  -- accept any certificate — no chain, hostname or expiry check. The supported way to probe a service you just booted with a self-signed cert; the handshake is still encrypted, only identity goes unchecked. Mutually exclusive with `ca_cert`., ca_cert?: string  -- PEM file whose certificates are ADDED to the default trust anchors (Mozilla's bundle + the platform store) — for an endpoint behind a private CA. Mutually exclusive with `insecure`. }
```

### `HttpProxyOpts`

```lua
prova.HttpProxyOpts{ upstream?: string  -- the real dependency's base url (needed by passthrough/record/auto), cassette?: string  -- the recording file (needed by record/replay/auto), mode?: string  -- "passthrough" (default) | "record" | "replay" | "auto", redact?: string[]  -- extra headers scrubbed at record time (defaults already cover auth) }
```

### `HttpResponse`

```lua
HttpResponse:json() -> table
```

Decode the body as JSON (raises on non-JSON).

```lua
HttpResponse:save(path: string) -> string path
```

Write the body to `path` byte-for-byte, creating parent directories, and return the path. The way to land a binary artifact on disk: `fs.write` takes a UTF-8 string and would reject those bytes.

```lua
prova.HttpResponse{ status: integer, body: string  -- the raw bytes; a Lua string is not UTF-8 constrained, so this is exact for binary, headers: table<string,string> }
```

### `JsonEncodeOpts`

```lua
prova.JsonEncodeOpts{ pretty?: boolean  -- indented output (default compact) }
```

### `JunitCase`

```lua
prova.JunitCase{ suite: string  -- the case's classname (or the enclosing <testsuite name>), name: string, outcome: "passed"|"failed"|"error"|"skipped", message?: string  -- the failure/error message (first line), when the deputy gave one, time_ms?: integer, file: string  -- the artifact the verdict was read from — the provenance }
```

One deputed case, as parsed from a JUnit XML result file.

### `JunitLoadOpts`

```lua
prova.JunitLoadOpts{ cwd?: string  -- base for a relative `results` pattern }
```

### `JunitReport`

```lua
prova.JunitReport{ total: integer, passed: integer, failed: integer, errors: integer, skipped: integer, flaky: integer  -- cases that failed and passed on the same tree, files: { path: string, mtime: integer }[], cases: prova.JunitCase[] }
```

### `JunitVerifyOpts`

```lua
prova.JunitVerifyOpts{ results: string  -- REQUIRED: where the deputy writes its XML (a path or glob), run?: string  -- the deputy's command; run tolerantly (its exit code is not the, cwd?: string  -- working directory for `run` and base for a relative `results` }
```

### `Matcher`

```lua
Matcher:contains(x: any)
```

Substring (strings) or membership (tables).

```lua
Matcher:eq(x: any)
```

Alias for `equals` (deep structural equality).

```lua
Matcher:equals(x: any)
```

Deep structural equality (recurses into tables).

```lua
Matcher:exists()
```

Present, for whatever the subject IS. A path string or a handle carrying `path` is resolved against the FILESYSTEM (the path exists, file or directory); anything else — a table, number, boolean — passes when it is simply non-nil. The string case is deliberate: asserting a file is there is this matcher's load-bearing use, so `expect("some value"):exists()` asks the filesystem and fails. For a string's presence, use `never():is_nil()`.

```lua
Matcher:gt(n: number)
```

Numeric `subject > n`.

```lua
Matcher:gte(n: number)
```

Numeric `subject >= n`.

```lua
Matcher:has_length(n: integer)
```

`#subject == n` — a string's byte length or a sequence's element count.

```lua
Matcher:is(x: any)
```

Identity: the *same* table/function/userdata (by reference), or an equal primitive (`rawequal`). Use over `equals` when you mean "the same object" — including tables with function fields that deep-equals cannot compare.

```lua
Matcher:is_dir()
```

The path exists and is a directory.

```lua
Matcher:is_empty()
```

Empty for whatever the subject is: a string with no bytes, a table with no entries, or a path with no children (a directory with no entries, a file of zero bytes).

```lua
Matcher:is_false()
```

Strictly the boolean `false` (not merely falsy — `nil` fails).

```lua
Matcher:is_falsy()
```

Passes for `false` or `nil` only — `0` and `""` are truthy in Lua and FAIL here.

```lua
Matcher:is_file()
```

The path exists and is a regular file.

```lua
Matcher:is_fully_rendered()
```

Assert a rendered tree (a tree/dir handle, or a path string) has no leftover template markers — no `&#123;&#123;`, `&#123;%`, or `&#123;#` in any file's contents or path segments. GitHub Actions `$&#123;&#123; … &#125;&#125;` expressions are excluded. The signature archetype check.

```lua
Matcher:is_nil()
```

The subject is `nil`.

```lua
Matcher:is_one_of(options: any[])
```

The subject equals one of `options` (deep equality).

```lua
Matcher:is_true()
```

Strictly the boolean `true` (not merely truthy).

```lua
Matcher:is_truthy()
```

Passes for anything except `false`/`nil` — Lua truthiness, so `0` and `""` PASS.

```lua
Matcher:lt(n: number)
```

Numeric `subject &lt; n`.

```lua
Matcher:lte(n: number)
```

Numeric `subject &lt;= n`.

```lua
Matcher:matches(pattern: string)
```

Lua-pattern match (strings).

```lua
Matcher:matches_snapshot(opts?: string|{ name?: string, level?: "layout"|"content" })
```

Compare the subject against a stored `.snap` file colocated with the test (`snapshots/&lt;file>__&lt;key>.snap`). Pass `prova --update-snapshots` (`-u`) to (re)write it; a mismatch fails with a line diff, a missing snapshot writes a reviewable `.snap.new`. The subject may be a **string** (compared as-is) or a **path handle** — any table with a `path` field, e.g. `archetect.render` output or `out:file(rel)`. For a path handle, `level` selects how much is captured: `"layout"` (sorted relative paths — the render's shape; the default for a directory) or `"content"` (paths + each file's bytes). Keep `content` snapshots narrow.

```lua
Matcher:never() -> prova.Matcher
```

Return a negated matcher: `expect(x):never():contains("secret")`.

```lua
prova.Matcher{}
```

Fluent assertion matcher returned by `expect(subject)`. Matchers validate the subject's type at call time, so filesystem/shell/http subjects get domain-specific checks.

### `MeasureOpts`

```lua
prova.MeasureOpts{ set?: string  -- the baseline file, .prova/baselines/<set>.json (default "default"), direction?: "lower_is_better"|"higher_is_better"  -- default "lower_is_better" }
```

### `MockMatch`

```lua
prova.MockMatch{ method?: string  -- matched case-insensitively, path?: string  -- exact — a literal `:` is NOT a param (`/models/x:predict`), path_matches?: string  -- a Lua pattern (the same dialect as `:matches(pat)`), route?: string  -- a template: "/orders/:id" → `req.params.id`. Segment-wise, }
```

What a request must look like for a stub to answer it. Omitted fields don't constrain, so `m:on&#123; path = "/x" &#125;` matches any method. **First matching stub wins**, in declaration order.

### `MockOpts`

```lua
prova.MockOpts{ passthrough?: string  -- forward unmatched requests to this base URL — the dependency stays REAL, record?: string  -- write forwarded exchanges to this cassette on teardown (needs `passthrough`), replay?: string  -- answer from a cassette; no dependency, no network (excludes `passthrough`), redact?: string[]  -- extra header names to redact in the cassette (auth/cookies are redacted anyway), allow_handler_errors?: boolean  -- a raising `:reply` handler normally FAILS the owning scope at, network?: boolean|string  -- expose a `.network` vantage for a containerized/VM'd SUT to reach }
```

The observe dial. A proxy is not a second concept: it is a mock whose *unmatched* requests are forwarded rather than 404'd. Stubs always win, so you can stub one endpoint and let the rest reach the real service (partial mocking).

### `MockReply`

```lua
prova.MockReply{ status?: integer  -- default 200, json?: any  -- encoded as JSON; sets content-type unless you set it, body?: string  -- a raw body, headers?: table<string,string>, delay?: string  -- hold the response this long ("250ms") — fault injection }
```

A stub's response. `json` and `body` are mutually exclusive — a response has one body.

### `MockRequest`

```lua
prova.MockRequest{ method: string  -- "GET", "POST", … (uppercase), path: string  -- path only; the query string is parsed into `query`, query: table<string,string>  -- parsed and percent-decoded, headers: table<string,string>  -- header names lowercased (HTTP names are case-insensitive), body: string  -- the raw request bytes, json?: any  -- the body decoded, when it parses as JSON; nil otherwise, params: table<string,string>  -- captures from the stub's `route` (empty for other stubs), status?: integer  -- journal only: the status the mock answered with, matched?: boolean  -- journal only: whether a *stub* matched, source?: string  -- journal only: "stub" | "passthrough" | "replay" | "unmatched", error?: string  -- journal only: why a handler or upstream failed, if it did }
```

A request as the mock saw it. A handler's argument and a journal entry are the **same shape**, so `req.path` in a handler and `m:received()[1].path` in an assertion mean the same thing.

### `MockServer`

```lua
MockServer:on(match: prova.MockMatch) -> prova.MockStub
```

Register a stub. Returns the stub so you can `:reply(…)` it.

```lua
MockServer:received(filter?: { method?: string, path?: string }) -> prova.MockRequest[]
```

Everything the mock was asked, in order — **as data**, for the ordinary matchers to assert on (`t:expect(m:received()):has_length(1)`). There is no `verify(count, pattern)` DSL because `t:expect` already exists. Unmatched requests are recorded too: a call you did not predict is usually the most interesting thing a mock can tell you.

```lua
MockServer:stop()
```

Stop serving. Idempotent — the owning scope calls this too.

```lua
prova.MockServer{ url: string  -- "http://127.0.0.1:<port>", endpoint: string  -- the driver-target alias == url, host: string  -- "127.0.0.1", port: integer  -- the bound port (random, so parallel tests don't collide), network?: { url: string, host: string, port: integer }  -- cross-substrate vantage; present only with `network` }
```

A mock HTTP server: a real server, in this process, that you stub and then assert on. Grammar- shaped like any resource — wire `m.url` into the system under test exactly as you would a database's, and it is torn down with the scope that owns it.

### `MockStub`

```lua
MockStub:reply(reply: prova.MockReply|fun(req: prova.MockRequest): prova.MockReply)
```

Answer matching requests with `reply` — a response table (terse), or a **function** taking the request and returning one (general). The function is real Lua, run on this Lua state at request time while the coroutine driving the SUT is suspended, so it can compute from the request and close over test locals. That is why there is no response-templating language to learn.

```lua
prova.MockStub{}
```

### `Network`

```lua
Network:stop()
```

Remove the network. Idempotent; retries briefly while endpoints are still detaching.

```lua
prova.Network{ name: string }
```

A user-defined bridge network from `docker.network` — containers joined to it resolve each other by name/alias over Docker's embedded DNS. Manage it with `ctx:manage(net)` so it is removed on teardown, LIFO, *after* its containers.

### `NetworkVantage`

```lua
prova.NetworkVantage{ url: string  -- connection URL at the network authority (alias:container_port), host: string  -- the network alias (DNS name on the topology network), port: integer  -- the CONTAINER port (not the mapped host port), alias: string  -- the alias this resource answers to }
```

The address a resource is reached at from a given vantage. The host vantage (`resource.url`/ `host`/`port`) is the mapped port a host process — the test runner — uses; the network vantage (`resource.network`) is the alias + container port an in-network consumer — a containerized SUT joined to the same topology network — uses.

### `PackageInfo`

```lua
prova.PackageInfo{ dir: string  -- the directory holding this package's own entry file — its real home, wherever it is consumed (`prova.root` is the CONSUMING package's root) }
```

The per-package info table, bound only inside a loaded package's own chunks. Not `package` — that is Lua's module table, and shadowing it would take `require` away from exactly the code that needs it.

### `Process`

```lua
Process:output() -> string
```

The process's combined stdout+stderr so far (bounded: last 64KB, oldest dropped). Never-blind boots: assert on it, or print it when readiness times out.

```lua
Process:running() -> boolean
```

Whether the process is still running (reaps it if it has already exited).

```lua
Process:stop()
```

Kill the process — and on unix its whole process group, so a booted app's workers die with it (docs/design/verifiers.md#conduct-process-group-reaping) — then reap it. Idempotent.

```lua
Process:wait() -> integer|nil
```

Wait for the process to exit; returns its exit code (or nil if signalled / already reaped).

```lua
prova.Process{ pid: integer|nil  -- OS process id (nil if it could not be determined) }
```

A long-running process from `shell.spawn`. Prefer `ctx:defer(function() proc:stop() end)` so it is stopped during teardown; `stop`/`wait` are async.

### `RecvOpts`

```lua
prova.RecvOpts{ timeout?: string, where?: prova.Where  -- read on until the turn that MATCHES (structural subset match) }
```

Options for reading one turn from a stream session (stdio, socket, websocket).

### `RemindOpts`

```lua
prova.RemindOpts{ when: fun(account: prova.ReminderAccount): boolean|string|nil  -- the trigger: falsy → watching; true → due; a string → due, with the string as the report's "why", requires?: string[]  -- capability expressions gating evaluation — unmet → UNEVALUATED, never watching }
```

### `ReminderAccount`

```lua
prova.ReminderAccount{ passed: integer  -- leaves that passed in this run, failed: integer  -- leaves that failed in this run, skipped: integer  -- leaves that skipped in this run, promised: integer  -- open promises in this run (the `promised` count of the headline), owed: integer  -- the ledger's remainder, as `prova owed` counts it (promises + claims) }
```

The read-only view of the run's account a reminder condition receives — evaluated after the proofs complete, so "all proofs green" / "nothing owed" are one-line conditions. Carries NO reminder state: reminders cannot observe reminders.

### `RenderOpts`

```lua
prova.RenderOpts{ source: string  -- local path or git URL, answers?: table<string,any>  -- prompt answers as data, switches?: string[], defaults?: boolean  -- use defaults for unanswered prompts (headless), destination?: string  -- optional; a temp dir is used if omitted }
```

### `RenderResult`

```lua
prova.RenderResult{ writes: table[]  -- ordered WriteFile/WriteDirectory ops }
```

A render result: a `Tree` plus the ordered IO-protocol write operations it intended.

### `ReportOpts`

```lua
prova.ReportOpts{ name: string  -- REQUIRED: the address — `prova reports <name>`, stable across runs, summary: string  -- REQUIRED: one line saying what the artifact shows. The only thing, forms: table  -- REQUIRED: renderings of the same fact, `{ json = path, html = path }`, explains?: string|string[]  -- measurement name(s) this artifact is the evidence for, so a }
```

### `ResourceRef`

```lua
prova.ResourceRef{}
```

An opaque, typed resource reference from `prova.writes`/`prova.reads`/`prova.port`. Prefer these constructors over magic-format strings like `"port:8080"` — the prefix in a bare string is a convention you can typo silently; a constructor cannot be.

### `RetryOpts`

```lua
prova.RetryOpts{ timeout?: string  -- overall deadline (default "30s"), every?: string  -- interval between attempts (default "500ms"), message?: string  -- error message on timeout }
```

### `SarifFinding`

```lua
prova.SarifFinding{ tool: string, rule: string, level: "error"|"warning"|"note"|"none"  -- a result with no level reads as "warning", message: string, uri: string  -- the first physical location, line?: integer, file: string  -- the SARIF artifact it was read from — the provenance }
```

### `SarifReport`

```lua
prova.SarifReport{ total: integer, errors: integer, warnings: integer, notes: integer, files: { path: string, mtime: integer }[], cases: prova.SarifFinding[] }
```

### `SarifVerifyOpts`

```lua
prova.SarifVerifyOpts{ results: string  -- REQUIRED: where the linter writes its SARIF (a path or glob), run?: string  -- the linter's command, run tolerantly, with freshness enforced, cwd?: string  -- working directory for `run` and base for a relative `results`, level?: "error"|"warning"|"note"  -- the threshold; findings at or above it count (default "error"), max?: integer  -- findings tolerated at or above `level` (default 0) }
```

### `Scope`

```lua
prova.Scope{ Test: prova.ScopeRef, Flow: prova.ScopeRef, File: prova.ScopeRef, Suite: prova.ScopeRef, Run: prova.ScopeRef }
```

Typed fixture-scope constants (the `scope` argument to `prova.fixture`): * `Scope.Test` — rebuilt fresh for each test (the default). * `Scope.Flow` — built once per `prova.flow`, shared across its steps. * `Scope.File` — built once per file, shared across the file's tests. * `Scope.Suite` — built once per suite (a group of files sharing one state; see `suite.lua`). * `Scope.Run` — conducted once per RUN, shared across every suite and worker; the value is plain data (each reader gets a copy) — the shared-deputy scope (`prova learn fixtures`).

### `ScopeRef`

```lua
prova.ScopeRef{ scope: string  -- the scope name ("test"|"flow"|"file"|"suite"|"run") }
```

An opaque fixture-scope value — a member of the `Scope` global.

### `Screen`

```lua
Screen:cell(row: integer, col: integer) -> { char: string, fg: string, bg: string, bold: boolean, dim: boolean, italic: boolean, underline: boolean, reverse: boolean, blink: boolean, conceal: boolean, strikethrough: boolean }
```

One styled cell (0-based row, col) with named ANSI colors ("red", "idx-208", "#ff0010") and every SGR attribute. A `conceal`ed cell still reports its `char`, as a real terminal holds it — `conceal` says it is not displayed (the masked-password assertion).

```lua
Screen:contains(s: string) -> boolean
```

Whether the rendered frame contains `s`.

```lua
Screen:line(n: integer) -> string
```

One grid ROW (0-based — screen geometry is coordinates, not Lua arrays). A soft-wrapped line spans several rows, as it spans several rows of `cell`; `contains` still sees the whole line.

```lua
Screen:snapshot_text() -> string
```

The snapshot protocol: what `t:expect(screen):matches_snapshot(name)` compares (the frame text).

```lua
Screen:text() -> string
```

The cursor: 0-based `row`/`col`; `visible` (DECTCEM); `shape` — what the program asked for with DECSCUSR, "default" while it never asked (not the same claim as "block"); `blink`, nil while the program never said. The window title the program set (OSC 0/2); "" when it never did. Whether the program is on the alternate screen (`?1049` and kin). The input modes the program switched on: application cursor keys (`?1`), bracketed paste (`?2004`), and any mouse reporting. The rendered frame text.

```lua
prova.Screen{ rows: integer, cols: integer, cursor: { row: integer, col: integer, visible: boolean, shape: "default"|"block"|"underline"|"bar", blink: boolean? }, title: string, alternate_screen: boolean, modes: { application_cursor: boolean, bracketed_paste: boolean, mouse_reporting: boolean } }
```

### `Selection`

```lua
prova.Selection{ keywords: string[], keyword_excludes: string[], tags: string[], tag_excludes: string[], nodes: string[], covering: string[]  -- claim addresses whose covering proofs were selected (`--covering`), lane_tags: string[], lane_tag_excludes: string[], is_empty: boolean  -- no axis set — an unselected (full) run }
```

The run's resolved selection (docs/design/verifiers.md#selection-pushdown-into-conducts): what `-k`/`--tags`/`--node` and the lane's baked tags resolved to, exposed so a deputy can narrow its conduct in its framework's own grammar. Plain data; mutating it changes nothing.

### `Session`

```lua
Session:eof()
```

Half-close stdin — "the client went away". A distinct act from `:stop()`, and the way to prove a server shuts down cleanly: `sess:eof()` then `sess:wait()`.

```lua
Session:expect(pattern: string, opts?: prova.ExpectOpts)
```

Observe-until-match: block until the stream shows `pattern` (a plain substring). The unframed sibling of `recv&#123; where &#125;` — use it to wait for a readiness line before the first request.

```lua
Session:recv(opts?: prova.RecvOpts) -> any
```

Read the next turn — or with `where`, the next turn that MATCHES, skipping (but still transcribing) the ones that do not. Bounded: 10s by default, loud on timeout or EOF, and the failure carries the stderr tail plus the child's state.

```lua
Session:send(data: any)
```

Write one turn. A table when `codec = "json"`, a string otherwise. Async.

```lua
Session:stderr() -> string
```

The bounded stderr tail (last 64KB, oldest dropped). NEVER part of the frame stream: a server logging to stderr is normal, and folding it into stdout would feed log lines to the decoder.

```lua
Session:stop()
```

Kill the process — and its whole group, so a server's workers die with it — then reap. Idempotent; what `ctx:manage` calls at scope end.

```lua
Session:transcript() -> table[]
```

The direction-tagged record of the conversation: `&#123; seq, dir = "in"\|"out", data &#125;[]`.

```lua
Session:wait(opts?: { timeout?: string }) -> integer|nil
```

Wait for exit; returns the exit code (nil if signalled or already reaped). Bounded (30s).

```lua
prova.Session{ pid: integer|nil  -- OS process id (nil if it could not be determined) }
```

A live conversation with a spawned process. `shell.spawn` boots a thing and probes it from outside (its stdin is nulled, deliberately); this is for a SUT whose protocol IS a conversation — an MCP server, an LSP server, a REPL — where the next write depends on the last read. Torn down with the scope.

### `ShellOpts`

```lua
prova.ShellOpts{ cwd?: string, env?: table<string, string|number|boolean>  -- scalars coerce — ports stay numbers, timeout?: string  -- wall-clock outer bound, e.g. "120s" — prices the whole task, idle_timeout?: string  -- liveness bound, e.g. "90s": kill only when a window passes with NO bytes on either stream AND no CPU progress (native readers; bytes-only where none exists) — bounds death, never work (composes with `timeout`), first_byte?: string  -- start-up bound, e.g. "30s": kill if NOTHING arrives on either stream within this long of spawn — the "it never answered" clock (a wedged daemon), disarmed for good by the first byte; "0s" disables, check?: boolean  -- non-zero exit raises, carrying the tail of BOTH stdout and stderr, merge_stderr?: boolean  -- fold stderr into stdout (the portable replacement for `2>&1`); stderr is then empty, stdin?: string  -- feed the program's stdin (the portable replacement for `printf x | cmd`), sample?: prova.ShellSample  -- capture a CPU profile of a matching child once it has run this long (diagnosing a slow conduct) }
```

### `ShellProxyOpts`

```lua
prova.ShellProxyOpts{ as: string, upstream?: string, cassette?: string, mode?: string, redact?: string[] }
```

### `ShellResult`

```lua
ShellResult:ok() -> boolean
```

Whether the command succeeded (`code == 0`). Sugar for the common check — `shell.run` does not raise on a non-zero exit unless you pass `opts.check`.

```lua
prova.ShellResult{ code: integer, stdout: string, stderr: string, duration: number  -- seconds }
```

### `ShellSample`

```lua
prova.ShellSample{ after: string  -- how long into the run to sample, e.g. "60s", matching: string  -- a substring of the command line to sample, into: string  -- the directory the sample is written to }
```

`shell.run`'s `sample`: every key required, none other taken.

### `ShellShim`

```lua
ShellShim:close()
```

Alias for `:stop()` — the proxy grammar's teardown verb.

```lua
ShellShim:on(match: { argv: string[] }) -> prova.ShellShimStub
```

Stub invocations whose argv starts with this prefix: `&#123; argv = &#123; "status" &#125; &#125;` answers `git status` (and `git status --short`). Stubs always win over the upstream.

```lua
ShellShim:received(filter?: table|fun(entry: table): boolean) -> table[]
```

The §6 journal, one entry per invocation: `&#123; seq, argv, stdin, matched, source &#125;` where source is "stub" \| "target" (forwarded) \| "unmatched". Filter by subset table or predicate.

```lua
ShellShim:stop()
```

Remove the shim and its journal (what `ctx:manage` calls). In record mode, the cassette flush point.

```lua
prova.ShellShim{ env: table<string,string>  -- PATH-prefixed env — hand to whatever spawns the SUT, path: string  -- the shim's absolute path }
```

### `ShellShimStub`

```lua
ShellShimStub:reply(reply: { stdout?: string, code?: integer })
```

Answer matching invocations synthetically: `&#123; stdout?, code? &#125;` (code defaults to 0).

```lua
prova.ShellShimStub{}
```

### `SocketConn`

```lua
SocketConn:close()
```

Close the connection (also what `ctx:manage` calls at scope end).

```lua
SocketConn:recv(n_or_opts?: integer|{ timeout?: string, where?: prova.Where }, opts?: prova.RecvOpts) -> any
```

Framed: read one whole turn — `recv(opts?)`. Raw: read exactly n bytes — `recv(n, opts?)`. Errors loud on timeout (default 10s) or a closed connection; never hangs. `where` reads on until a turn MATCHES — the reply to request 3, skipping the notifications that arrive first. Skipped turns are counted in the timeout message, so "nothing arrived" and "nothing matched" read differently.

```lua
SocketConn:send(data: any)
```

Write one turn (framed) or raw bytes (no framing). A table when `codec = "json"`, a string otherwise. Async.

```lua
prova.SocketConn{}
```

### `SocketConnectOpts`

```lua
prova.SocketConnectOpts{ addr: string, framing?: prova.SocketFraming, codec?: prova.Codec }
```

### `SocketListenOpts`

```lua
prova.SocketListenOpts{ addr?: string, framing?: prova.SocketFraming, codec?: prova.Codec }
```

### `SocketListener`

```lua
SocketListener:accept(opts?: { timeout?: string }) -> prova.SocketConn
```

Accept one connection (async, timeout'd — default 10s).

```lua
SocketListener:stop()
```

Stop listening (what `ctx:manage` calls; a unix socket path is reaped).

```lua
prova.SocketListener{ addr: string  -- the resolved address ("tcp://127.0.0.1:<port>" / "unix://…") }
```

### `SocketMock`

```lua
SocketMock:on(turn_or_shape: any) -> prova.SocketStub
```

Stub one framed turn: exact bytes (a string), or — under `codec = "json"` — a SHAPE, subset-matched against the decoded turn with the same matcher `recv&#123; where &#125;` uses. First matching stub wins; an unmatched turn is journaled (§6: matched=false, source="unmatched") and the connection closes LOUD.

```lua
SocketMock:received(filter?: table|fun(entry: table): boolean) -> table[]
```

The §6 journal: `&#123; seq, data, matched, source &#125;[]`, filterable by subset table or predicate.

```lua
SocketMock:stop()
```

Stop the mock (what `ctx:manage` calls).

```lua
prova.SocketMock{ addr: string  -- endpoint symmetry: the same string a driver's connect takes, endpoint: string  -- the driver-target alias == addr }
```

### `SocketMockOpts`

```lua
prova.SocketMockOpts{ addr?: string, framing: prova.SocketFraming, codec?: prova.Codec }
```

### `SocketProxy`

```lua
SocketProxy:after(delay: string) -> prova.SocketProxy
```

Put a fuse on any fault: `p:after("500ms"):drop()` — healthy first, injured later.

```lua
SocketProxy:close()
```

Alias for `:stop()` — the proxy grammar's spelling; in record mode it flushes the cassette.

```lua
SocketProxy:corrupt()
```

Corrupt bytes in flight (length preserved, contents not).

```lua
SocketProxy:drop()
```

Sever every live connection and refuse new ones. Loud, immediate.

```lua
SocketProxy:latency(duration: string)
```

Continuous latency on every turn/chunk, both directions ("2s", "300ms").

```lua
SocketProxy:stop()
```

Stop the proxy (what `ctx:manage` calls). In a record cassette mode, the flush point.

```lua
SocketProxy:throttle(rate: string)
```

Rate-limit the stream ("8kbps", "1mbps").

```lua
SocketProxy:transcript() -> table[]
```

The direction-tagged transcript: `&#123; seq, dir ("up"\|"down"), data &#125;[]` — framed: turns; raw: chunks.

```lua
prova.SocketProxy{ addr: string  -- dial this instead of the upstream — the wiretap is transparent }
```

### `SocketProxyOpts`

```lua
prova.SocketProxyOpts{ upstream?: string, addr?: string, framing?: prova.SocketFraming, cassette?: string, mode?: string, redact?: string[] }
```

### `SocketStub`

```lua
SocketStub:reply(data: any)
```

Answer this turn with `data` (framed onto the wire). A table when `codec = "json"`.

```lua
prova.SocketStub{}
```

### `SpawnOpts`

```lua
prova.SpawnOpts{ cwd?: string, env?: table<string, string|number|boolean>  -- scalars coerce — ports stay numbers }
```

### `StdioMock`

```lua
StdioMock:close()
```

Alias for `:stop()`.

```lua
StdioMock:on(turn_or_shape: any) -> prova.StdioStub
```

Stub one turn: an exact turn (a string), or — under `codec = "json"` — a SHAPE, subset-matched against the decoded turn. The shape form is the one an MCP or LSP stub wants: it keys on a field (`&#123; method = "tools/list" &#125;`), never on an exact serialization.

```lua
StdioMock:received(filter?: table|fun(entry: table): boolean) -> table[]
```

The §6 journal: `&#123; seq, data, matched, source &#125;[]`, filterable by subset table or predicate.

```lua
StdioMock:stop()
```

Stop the mock and remove the shim (what `ctx:manage` calls).

```lua
prova.StdioMock{ env: table<string,string>  -- PATH-prefixed env — hand to whatever spawns the SUT, path: string  -- the shim's absolute path }
```

### `StdioMockOpts`

```lua
prova.StdioMockOpts{ as: string, framing: prova.SocketFraming, codec?: prova.Codec }
```

### `StdioProxy`

```lua
StdioProxy:close()
```

Alias for `:stop()` — the proxy grammar's teardown verb.

```lua
StdioProxy:drop()
```

Sever the session: the SUT sees its server go away mid-conversation.

```lua
StdioProxy:latency(d: string)
```

Delay every turn ("300ms") — the turn-level fault. `corrupt`/`throttle` are BYTE-level and are refused here, naming `socket.proxy`, which is where a byte-level wiretap lives.

```lua
StdioProxy:stop()
```

Stop the proxy (what `ctx:manage` calls). In record mode, the cassette's flush point.

```lua
StdioProxy:transcript() -> table[]
```

The direction-tagged record: `&#123; seq, dir = "up"\|"down", data &#125;[]`.

```lua
prova.StdioProxy{ env: table<string,string>  -- PATH-prefixed env — hand to whatever spawns the SUT, path: string  -- the shim's absolute path }
```

### `StdioProxyOpts`

```lua
prova.StdioProxyOpts{ as: string, upstream?: string|string[], framing: prova.SocketFraming, cassette?: string, mode?: string, redact?: string[] }
```

### `StdioSpawnOpts`

```lua
prova.StdioSpawnOpts{ cmd: string|string[], framing?: prova.SocketFraming, codec?: prova.Codec, cwd?: string, env?: table<string,string|number|boolean> }
```

### `StdioStub`

```lua
StdioStub:reply(data: any)
```

Answer this turn. A table when `codec = "json"`, a string otherwise.

```lua
prova.StdioStub{}
```

### `SuiteConfig`

```lua
prova.SuiteConfig{ name?: string  -- display name for the suite (default: the directory name), requires?: string[]  -- capabilities gating the whole suite — unmet → every file skips, switch?: string  -- an opt-in class for every file in the suite: off unless thrown }
```

### `Term`

```lua
Term:expect(pattern: string, opts?: { timeout?: string })
```

Block until the output transcript contains `pattern` (plain bytes), with a timeout (default 10s) — observe-until-match, never a sleep. The failure carries the current screen.

```lua
Term:resize(cols: integer, rows: integer)
```

Resize the pty (a real SIGWINCH the program observes — `stty size` reports the new numbers).

```lua
Term:screen() -> prova.Screen
```

A frozen frame of the screen — plain data, safe to assert on.

```lua
Term:send(data: string)
```

Write bytes to the pty (include "\r" to press enter).

```lua
Term:signal(name: string)
```

Deliver a POSIX signal to the child ("INT", "TERM", …) — prove clean Ctrl-C handling.

```lua
Term:stop()
```

Kill the child and close the pty (what `ctx:manage` calls).

```lua
Term:wait(opts?: { timeout?: string }) -> { code: integer }
```

Reap the child and report `&#123; code &#125;` (polls; default timeout 30s).

```lua
Term:wait_stable(opts?: { timeout?: string })
```

Settle the frame: returns once output has been quiet for a beat (or at EOF). The anti-sleep.

```lua
prova.Term{}
```

### `TerminalMock`

```lua
TerminalMock:expect(pattern: string) -> prova.TerminalMockStep
```

Script one expectation: `fake:expect("password:"):send("hunter2\n")`.

```lua
TerminalMock:stop()
```

Remove the shim (what `ctx:manage` calls).

```lua
prova.TerminalMock{ env: table<string,string>  -- PATH-prefixed env — hand to whatever spawns the SUT, path: string  -- the shim's absolute path }
```

### `TerminalMockOpts`

```lua
prova.TerminalMockOpts{ as: string }
```

### `TerminalMockStep`

```lua
TerminalMockStep:send(reply: string)
```

Complete the pair: when stdin contains the expected bytes, answer with `reply`.

```lua
prova.TerminalMockStep{}
```

### `TerminalProxy`

```lua
TerminalProxy:close()
```

Alias for `:stop()` — the proxy grammar's teardown verb.

```lua
TerminalProxy:stop()
```

Stop the proxy (what `ctx:manage` calls). In record mode, flushes the cassette (outside the shim dir) — the close/scope-exit flush point.

```lua
prova.TerminalProxy{ env: table<string,string>  -- PATH-prefixed env — hand to whatever spawns the SUT, path: string  -- the shim's absolute path }
```

### `TerminalProxyOpts`

```lua
prova.TerminalProxyOpts{ as: string, upstream?: string, cassette?: string, mode?: string }
```

### `TerminalSpawnOpts`

```lua
prova.TerminalSpawnOpts{ cmd: string[], cols?: integer, rows?: integer, cwd?: string, env?: table<string,string> }
```

### `Test`

```lua
prova.Test{}
```

A test handle returned by `prova.test`/`prova.test_each`. Pass to `depends_on`.

### `TestContext`

```lua
TestContext:advise(entry: { family: string, was: integer, now: integer })
```

Report an advisory measure that moved: `family` went from `was` to `now`. It returns, and it changes no verdict and no tally, so a test may advise several families and then pass or skip as before. Each is sent as an `advice` event (`&#123;type, path, family, was, now&#125;`) just before the test's `node_finished`, so a reader (a gate, a bot) acts on it by kind, never by a skip's words. For a census ruled advisory: say what grew here, then skip with the human sentence.

```lua
TestContext:expect(subject: any, label?: string) -> prova.Matcher
```

Start a fluent assertion. The optional `label` is used in the failure message, so a failed check reads e.g. "order id: expected truthy, got nil" instead of pointing at an anonymous value.

```lua
TestContext:expect_all(body: fun())
```

Soft assertions: collect every failure inside `body` before failing the test. Reports all failures, not just the first.

```lua
TestContext:skip(reason: string)
```

Skip the current test at runtime with a reason.

```lua
prova.TestContext{ name: string  -- resolved test name, case: table|nil  -- current case (parametrized tests) }
```

Context passed to test bodies. Extends `prova.Context` with assertions and control flow.

### `TestOpts`

```lua
prova.TestOpts{ promises?: string  -- a proof authored AHEAD of its implementation; the value is the mandatory reason. Red reports PROMISED (CI green); green FAILS until it graduates to `proves` in the same commit (`prova learn promises`), proves?: string  -- the kept promise's context — runtime-inert; a non-empty string; never together with `promises`, covers?: string  -- the prose claim this proof discharges: "docs/design.md#claim-id", optionally pinned "@<hash>" (`prova learn claims`), falsified_by?: fun(t: prova.TestContext)  -- a mutation the body must catch; applied only by `prova tests falsify`, which inverts the verdict (`prova learn falsify`), inputs?: string[]  -- package-relative paths or globs; `--reuse` carries a prior pass forward while they are byte-identical, idle_timeout?: string  -- e.g. "60s" — the LIVENESS bound, spelled as `shell.run` spells it: fail only when a window passes with no sign of life (no assertion lands), never merely because the work is slow. Bounds death, never work — so it can be generous where a wall clock has to be a guess. Progress at test scope is ASSERTIONS (prova captures no test output), so a body doing real work without asserting looks wedged from here: that is why it is opt-in. Defaults ON under `prova tests falsify`, where a mutant that stops answering is the expected failure (`prova learn falsify`). }
```

### `Tree`

```lua
Tree:dir(rel: string) -> prova.DirHandle
```

A handle to a directory at `rel` within this tree.

```lua
Tree:file(rel: string) -> prova.FileHandle
```

A handle to a file at `rel` within this tree — chain matchers off it (`expect(t:file("a.txt")):exists()`).

```lua
Tree:tree() -> table
```

Serializable snapshot of the whole layout (for `:matches_snapshot()`).

```lua
prova.Tree{ path: string  -- absolute root }
```

A tree handle rooted at a directory (e.g. a render destination).

### `UnitOpts`

```lua
prova.UnitOpts{ tags?: string[]  -- selection tags (select with `--tags a,b`; `!tag` excludes), free-form, requires?: prova.Capability[]  -- skip (not fail) if a capability is unavailable, depends_on?: prova.Unit[]  -- skip this unit if any upstream failed/was skipped, locks?: prova.ResourceRef[]  -- locks held while running: `prova.writes`/`prova.reads`/`prova.port` — bound across every prova instance (`prova learn locks`), resources?: prova.ResourceRef[]  -- DEPRECATED spelling of `locks`: still honored, with a warning; retires at 1.0, serial?: boolean  -- never run concurrently with anything else in THIS run (a rule binding other instances is a lock), switch?: string  -- an opt-in class: off unless a lane's `switches` or `-s` throws it, timeout?: string  -- e.g. "30s" — the WALL-CLOCK bound (enforced per test and per flow step) }
```

Options shared by any schedulable unit (test/flow/group). These classes ARE the accepted set: build.rs generates the runtime's closed option table from them, so a field missing here is an option the runtime refuses.

### `UrlParts`

```lua
prova.UrlParts{ scheme: string, host?: string, port?: integer  -- written, or the scheme's well-known default, path: string, query?: string, fragment?: string }
```

### `VerifyChecks`

```lua
prova.VerifyChecks{ name?: string  -- label for the generated tests (default "archetype"), project_dir?: string  -- assert relative to this subdirectory the render produces, expected_files?: string[]  -- must exist (relative to project_dir), absent_files?: string[]  -- must NOT exist, yaml_globs?: string[]  -- each glob must match ≥1 file; each match must parse, fully_rendered?: boolean  -- assert no leftover template markers (default true), requires?: string[]  -- capabilities gating the build step (else skip), build_steps?: (string|string[])[]  -- commands run sequentially in project_dir, env?: table<string,string>  -- extra environment for build_steps, timeout?: string  -- per build step (default "600s") }
```

The checks `archetect.verify` registers against a rendering — prova's answer to the pytest harness's `manifest.yaml`, matched field-for-field but as real Lua you can extend.

### `VerifySpec`

```lua
prova.VerifySpec{ source: string  -- local path or git URL, answers?: table<string,any>  -- prompt answers as data, switches?: string[], defaults?: boolean  -- headless defaults for unanswered prompts (default true), scope?: prova.Scope  -- scope of the render fixture it creates (default Scope.File) }
```

The one-shot form's spec: the checks plus the render itself. Anything a prompt needs and the answers omit falls back to its default; a prompt with no default and no answer errors (headless never hangs).

### `WaitOpts`

```lua
prova.WaitOpts{ status?: integer  -- expected status (default 200), headers?: table<string,string>  -- sent on every poll — how a health endpoint behind auth is waited on; on `client:wait_for` these layer OVER the client's defaults by name, timeout?: string  -- give up after this long, e.g. "30s", every?: string  -- poll interval, e.g. "500ms", insecure?: boolean  -- accept any certificate — no chain, hostname or expiry check. The supported way to probe a service you just booted with a self-signed cert; the handshake is still encrypted, only identity goes unchecked. Mutually exclusive with `ca_cert`., ca_cert?: string  -- PEM file whose certificates are ADDED to the default trust anchors (Mozilla's bundle + the platform store) — for an endpoint behind a private CA. Mutually exclusive with `insecure`. }
```

Deliberately NOT an extension of `prova.HttpOpts`: the polling verbs honor these keys and nothing else, and since an option prova cannot honor is refused rather than dropped (docs/design/agent-ergonomics.md#module-opts-silently-ignored), advertising `json` or `redirects` here would hand an author a call that fails. The TLS pair IS here: readiness is the first thing to touch a service prova just booted, so a poll that could not accept a self-signed certificate would make boot-then-probe the one place TLS stops (architecture.md#tls-everywhere).

### `WebsocketConnectOpts`

```lua
prova.WebsocketConnectOpts{ url: string, codec?: prova.Codec, insecure?: boolean, ca_cert?: string }
```

### `WebsocketMockOpts`

```lua
prova.WebsocketMockOpts{}
```

### `WebsocketProxyOpts`

```lua
prova.WebsocketProxyOpts{ upstream: string, insecure?: boolean, ca_cert?: string }
```

### `Workspace`

```lua
Workspace:close()
```

Remove the workspace tree now (teardown calls this automatically at scope end).

```lua
Workspace:exists(rel: string) -> boolean
```

Whether a relative path exists.

```lua
Workspace:file(rel: string) -> string
```

Absolute path of a file inside the workspace (no I/O — just the join).

```lua
Workspace:read(rel: string) -> string
```

Read a relative path's contents.

```lua
Workspace:write(rel: string, contents: string) -> string
```

Write `contents` to a relative path (parent directories are created) and return the absolute path.

```lua
prova.Workspace{ path: string  -- the workspace's absolute root directory }
```

A managed scratch directory. All relative paths resolve against `path`; teardown (via the owning scope) removes the whole tree.

### `WsConn`

```lua
WsConn:close()
```

Close the connection (the ws close handshake).

```lua
WsConn:recv(opts?: prova.RecvOpts) -> any
```

Receive the next message turn (async, timeout'd — default 10s; loud on close). `where` reads on until a turn matches, exactly as on a socket.

```lua
WsConn:send(data: any)
```

Send one message turn. A table when `codec = "json"`, a string otherwise. Async.

```lua
prova.WsConn{}
```

### `WsMock`

```lua
WsMock:on(turn: string) -> prova.WsStub
```

Stub one message turn (exact text). Unmatched turns are journaled (§6), never guessed at.

```lua
WsMock:on_connect(handler: fun(conn: prova.WsConn))
```

Full duplex: run this when a client connects — `conn:send(…)` pushes unprompted.

```lua
WsMock:received(filter?: table|fun(entry: table): boolean) -> table[]
```

The §6 journal: `&#123; seq, data, matched, source &#125;[]`, filterable by subset table or predicate.

```lua
WsMock:stop()
```

Stop the mock (what `ctx:manage` calls).

```lua
prova.WsMock{ url: string  -- "ws://127.0.0.1:<port>", endpoint: string  -- the driver-target alias == url }
```

### `WsProxy`

```lua
WsProxy:drop()
```

Sever the connection.

```lua
WsProxy:latency(duration: string)
```

Continuous latency on every message turn, both directions ("2s").

```lua
WsProxy:stop()
```

Stop the proxy (what `ctx:manage` calls).

```lua
WsProxy:transcript() -> table[]
```

The direction-tagged message transcript: `&#123; seq, dir ("up"\|"down"), data &#125;[]`.

```lua
prova.WsProxy{ url: string  -- "ws://127.0.0.1:<port>" — dial this instead of the upstream }
```

### `WsStub`

```lua
WsStub:reply(data: string)
```

Answer this message turn.

```lua
prova.WsStub{}
```
