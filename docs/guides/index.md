---
sidebar_position: 2.5
sidebar_label: "Guides"
---

# Guides

Step-by-step paths from nothing to a project held to a bar. Each guide ends with commands you ran
and output you saw, and links out to the sections that explain the parts in depth.

The four guides form one path. Take them in order the first time; later, jump to the one you need.

| Guide | You finish with |
|---|---|
| [Set Up Your Agent](./set-up-your-agent.md) | `prova` installed, your coding agent connected over MCP, and the skill committed to the repository |
| [Bootstrap a Project](./bootstrap-a-project.md) | a project with a manifest, a black-box suite, quality lanes, committed baselines and CI |
| [Adopt a Standards Package](./adopt-a-standards-package.md) | the project held to your organization's shared bar, with exceptions recorded as dated waivers |
| [Bring a Project into Alignment](./bring-a-project-into-alignment.md) | an existing codebase with real debt on a ratchet: green today, unable to get worse, and scheduled to get better |

## The idea behind all four

Warnings and drift are fixed mechanically, not by asking people (or agents) to remember. Every rule
in these guides is a test: it fails the run when it is broken, prints why, and runs the same way on
a laptop and in CI. Debt that already exists is measured and frozen rather than demanded away on
day one, and an exception is a waiver with a reason and an end date rather than a silent `allow`.

The same material is in the binary: from prova 0.30.14, `prova learn quality` is the one-screen version, and an agent
connected over MCP reads it without leaving the editor.
