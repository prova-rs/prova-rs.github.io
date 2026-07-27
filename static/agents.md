# Set up Prova — instructions for a coding agent

You are an AI coding agent. This document is the official Prova setup procedure. Execute the steps
yourself — install the binary, connect it to whatever harness you are running in, and verify the
result. Do not hand these commands to the user to run.

Work through the steps in order. Stop and report if a step fails rather than continuing past it.

---

## What Prova is, in one paragraph

Prova is a proof-driven development toolkit: a single static Rust binary that renders, builds, boots,
and probes real systems, then holds them to an executable, black-box definition of done. Tests are
written in Lua. For you specifically, it is a verification arm — the thing that lets you *prove* a
change works instead of claiming it does. It exposes itself to agents two ways: an **MCP server**
(`prova mcp`) whose tools mirror the CLI, and an **embedded skill** (`prova skill`) that teaches the
discipline. Set up both.

---

## Step 1 — Install the binary

Prova has no runtime dependencies. Pick the first option that fits the machine.

**Homebrew (macOS and Linux):**

```bash
brew install prova-rs/tap/prova
```

**Release binary (Linux, or macOS without Homebrew):**

```bash
TAG=$(curl -fsSL https://api.github.com/repos/prova-rs/prova/releases/latest \
      | grep '"tag_name"' | head -1 | cut -d'"' -f4)
OS=$(uname -s | tr '[:upper:]' '[:lower:]'); [ "$OS" = "darwin" ] && OS=macos
ARCH=$(uname -m); [ "$ARCH" = "aarch64" ] && ARCH=arm64

curl -fsSLO "https://github.com/prova-rs/prova/releases/download/${TAG}/prova-${TAG}-${OS}-${ARCH}.tar.gz"
tar -xzf "prova-${TAG}-${OS}-${ARCH}.tar.gz"
sudo mv "prova-${TAG}-${OS}-${ARCH}/prova" /usr/local/bin/
```

Prebuilt archives exist for `linux-x86_64`, `linux-arm64`, `macos-arm64`, and `windows-x86_64`. There
is **no prebuilt macOS x86_64 archive** — on an Intel Mac, use Homebrew or build from source.

**From source (any platform with a Rust toolchain):**

```bash
cargo install --git https://github.com/prova-rs/prova prova-cli
```

---

## Step 2 — Verify the binary

```bash
prova --version
```

Expected: a version string such as `prova 0.9.1`. If the command is not found, `prova` is not on
`PATH` — fix that before continuing.

---

## Step 3 — Connect Prova to your harness

This is the step that matters most for you. Prova as an MCP server gives you `run`, `list`, `eval`,
`introspect`, and `learn` tools, plus warm topology tools (`up`, `down`, `status`) that hold a live
environment across calls so re-runs take milliseconds. The server's `instructions` field is the
embedded skill, so you understand Prova the moment you connect.

Find your harness below and run the matching setup.

### Claude Code

```bash
claude mcp add --scope user prova -- prova mcp
```

Then install the skill into the project so it persists in the repo:

```bash
prova skill --install
```

That writes `.claude/skills/prova/SKILL.md`. Tell the user to restart Claude Code (or start a new
session) — MCP servers are loaded at session start, so the `prova` tools will not appear in the
current session.

### Codex

```bash
codex mcp add prova -- prova mcp
```

### Cursor

Add to `~/.cursor/mcp.json` (or `.cursor/mcp.json` for a single project):

```json
{
  "mcpServers": {
    "prova": {
      "command": "prova",
      "args": ["mcp"]
    }
  }
}
```

### Windsurf

Add the same block to `~/.codeium/windsurf/mcp_config.json`.

### Any other MCP client

Prova is a plain **stdio** MCP server. Register it however your client expects, using:

- command: `prova`
- args: `["mcp"]`

If your client's config file lives somewhere other than the paths above, use its documented location
— the server definition is identical everywhere.

### No MCP support?

Prova works fine as a CLI. Ingest the skill directly and use commands instead of tools:

```bash
prova skill              # print the skill; read it
prova skill --install    # or persist it to .claude/skills/prova/SKILL.md
```

The contract is the same either way: if Prova is an MCP server, call tools; if it is a CLI, run
commands. Nothing else changes.

---

## Step 4 — Scaffold a project, if the repo needs one

First check whether the repo already has a Prova package — look for `prova.toml`, `prova/prova.toml`,
or `.prova/prova.toml`, walking up from the working directory. **If one exists, skip this step.**
`prova init` refuses to clobber an existing layout.

If there is none, scaffold one. Always pass `--headless --defaults` so it never blocks on an
interactive prompt:

```bash
prova init project --headless --defaults
```

This creates `.prova/` (manifest, runtime config, and a shared `lib` plugin), a `proofs/` starter
suite, and a `.luarc.json` for editor completion. Note that `.luarc.json` holds machine-local paths —
add it to `.gitignore`.

To scaffold a **plugin** instead (a package that exports a namespace others `require()`):

```bash
prova init plugin --headless --defaults
```

See the full catalog with `prova init --list`.

---

## Step 5 — Verify the setup end to end

**Confirm the suite runs:**

```bash
prova
```

Expected: the starter suite executes and reports passing tests, exiting `0`.

**If you connected over MCP**, confirm the tools answer. Call:

- `learn {}` — returns the topic catalog. This is your primary discovery rail; start here whenever
  you need to know how something in Prova works.
- `introspect {}` — returns every function, signature, and summary in the API, including any plugins
  the package declares. Use it instead of guessing at the API or probing by trial.

If both return content, the connection is live.

---

## Step 6 — Report completion

Show the user this summary, filling in what actually happened:

```
┌─────────────────────────────────────────────────────────┐
│  Prova is ready                                         │
│                                                         │
│  Binary      prova <version>                            │
│  MCP server  connected as "prova"                       │
│  Skill       .claude/skills/prova/SKILL.md              │
│  Project     <scaffolded | already present | none>      │
│                                                         │
│  Next: describe what the system must do, and I'll       │
│  write the proof before implementing it.                │
└─────────────────────────────────────────────────────────┘
```

If the harness needs a restart for MCP tools to load, say so explicitly.

---

## How to work with Prova once it is set up

Read this — it is the practice the whole tool exists to support.

1. **Write the proof first.** A proof is a black-box test of what a real caller observes at the
   system's boundary. Red is the correct state at this stage.
2. **Probe unknowns with `eval`** rather than guessing — it runs a one-shot Lua snippet in the full
   environment, no test file needed.
3. **Implement, then re-run only what is red** with `--last-failed` (or `run { last_failed = true }`).
4. **Never weaken a proof to make it pass.** Fix the system, or renegotiate the bar with the human.
   Deleting an assertion to get green is the one unforgivable move.
5. **Commit the suite and the implementation together** — a proof-carrying change.

Prova complements a language's own test harness rather than replacing it. Prove the **contract** with
Prova; prove the **internals** with native unit tests. Most changes want both.

Do not claim work is correct. Prove it.

---

## Reference

- Documentation — https://prova-rs.github.io/
- Getting started — https://prova-rs.github.io/docs/getting-started/
- CLI reference — https://prova-rs.github.io/docs/reference/cli
- Lua API — https://prova-rs.github.io/docs/reference/lua-api/
- Source and issues — https://github.com/prova-rs/prova
- Official plugins — https://prova-rs.github.io/docs/plugins/official-plugins
