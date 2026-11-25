---
sidebar_position: 5.5
sidebar_label: "Quality"
---

# Quality

The [evidence ledger](../evidence/index.md) asks whether everything a project claims is proven. The
**quality account** asks the neighboring questions: did the language's own test suite pass, did the
linter stay clean, did any measured debt grow, and does anything in the world need attention? Prova
answers all of them in the same run, with one exit code, so `prova` is the whole bar for a project
rather than one harness among several.

There are two ways to earn a green:

- **Witnessed** evidence is what a proof observed itself, at the system's boundary.
- **Deputed** evidence is a verdict another tool produced (cargo nextest, Maven Surefire, pytest,
  Jest, clippy, ESLint) that a proof ran and adopted. Prova never reaches inside the process; it
  conducts the specialist and observes it from outside, the same way it observes any system.

A deputed conduct hands back three things, and each has a home:

| What comes back | Where it goes | Page |
|---|---|---|
| Cases and findings (JUnit XML, SARIF) | the run's deputed account | [Deputed Verifiers](./deputed-verifiers.md) |
| Measurements (coverage, counts, sizes) | ratchets against committed baselines | [Ratchets](./ratchets.md) |
| Artifacts (an HTML coverage report, a junit file) | kept reports, addressable after the run | [Deputed Verifiers](./deputed-verifiers.md#kept-reports) |

How a project exposes all of this to the people and agents working on it is the job of
[Lanes](./lanes.md). Obligations the *world* creates, such as an upstream release or a backlog item
past its date, are [Reminders](./reminders.md).

## In this section

1. **[Deputed Verifiers](./deputed-verifiers.md)**: run the language's own tests and linters, adopt
   their verdicts, and keep their reports.
2. **[Ratchets](./ratchets.md)**: hold coverage, panics, sizes and lint counts to a committed floor
   that only moves toward better.
3. **[Lanes](./lanes.md)**: named run modes that give every project the same interface, and the
   Rust retrofit that sets them up in one command.
4. **[Reminders](./reminders.md)**: conditions the world must meet, watched on every run.

From prova 0.30.14, `prova learn quality` is the one-screen version of lanes, ratchets and standards packages. To put a
project on this bar step by step, follow [Bootstrap a Project](../guides/bootstrap-a-project.md) and
[Bring a Project into Alignment](../guides/bring-a-project-into-alignment.md).
