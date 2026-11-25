---
sidebar_position: 1
---

# Set Up Your Agent

Prova teaches itself. The binary carries an agent skill, a topic catalog (`prova learn`) and an
MCP server, so a coding agent learns how to use it from the binary rather than from a prompt you
maintain. This guide installs `prova`, connects an agent to it, and checks that the agent can see
it.

## 1. Install prova

```shell
brew install prova-rs/tap/prova
prova --version
```

Use 0.30.13 or later. Other channels (release archives, building from source) are on
[Installation](../getting-started/installation.md).

## 2. Connect your agent over MCP

`prova mcp` serves the CLI as MCP tools over stdio. For Claude Code, register it once for every
project:

```shell
claude mcp add --scope user prova -- prova mcp
```

Any other MCP client takes the same stdio command: `prova mcp`.

The server sends the agent skill as its connection instructions, so the agent knows the practice
(write the proof first, run only what is red, never weaken a proof to pass it) the moment it
connects. The server resolves the package from its working directory, and any call can name
another with `package`. [Agents & MCP](../running-prova/agents-and-mcp.md) lists the tools.

## 3. Commit the skill to the repository

In each repository that uses prova, write the skill where agents look for it, and commit it:

```shell
prova skill --install    # writes .claude/skills/prova/SKILL.md
```

A committed skill reaches every teammate's agent, including one with no MCP server configured.
The skill is generated from the binary, so re-run the command after upgrading prova.

## 4. Check the agent can see prova

From a terminal in the repository:

```shell
prova learn            # the topic catalog
prova learn project    # this package's shape: proof directories, lanes, house rules
```

Then ask the agent a question only the binary can answer, such as *"What does `prova learn
project` say about this repository?"* or *"Which lanes does this project have?"* An agent connected
over MCP calls the `learn` or `list` tool; one using the skill runs the command. Either way it
answers with this project's facts, not a guess.

## What the agent does from here

The skill tells the agent to ask the binary before guessing: `prova learn <topic>` for a concept,
`prova introspect <name>` for an API's signature, `prova eval '<lua>'` to try something. Topics
render with your project's own facts, so `prova learn quality` names your lanes rather than an
example's.

## Next

[Bootstrap a Project](./bootstrap-a-project.md): give the repository a suite and quality lanes.
