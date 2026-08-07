---
sidebar_position: 8
sidebar_label: "Patterns"
---

# Patterns

The rest of this site documents what Prova *does*. This section documents what teams *do with
it* — shapes extracted from production use across several organizations, written so you can adopt
one wholesale. A pattern page is not a feature tour: it starts from the problem the field
actually had, shows the shape that survived contact with it, states the rules that make the shape
work, and names the failure modes real fleets already hit so you don't have to hit them again.

Every pattern here is running somewhere today. The code excerpts are adapted (a neutral `acme`
stands in for the organizations involved), but the shapes, the rules, and the war stories are
verbatim from the field.

## The catalog

| Pattern | What it solves |
|---|---|
| [The Shared Standards Package](./shared-standards-package.md) | One org-wide `prova-acme-standards` package holds a whole fleet of repositories to the same bar — standards as proofs, waivers as visible debt, a spec bump as a fleet-wide ratchet. |
| [Publishing Topologies](./publishing-topologies.md) | A package that advertises a whole environment, not just clients — one factory behind both your proofs and `prova up`, with the dual-vantage networking contract proven rather than assumed. |
| [Org Init Catalogs & Nightly Lanes](./org-catalogs-and-nightlies.md) | Two supporting shapes: baking org defaults into `prova init`, and keeping network-touching freshness checks out of the merge gate without losing them. |

The catalog grows with upcoming releases — pages for shapes built on features still incubating
land here as those features ship.

## How to read a pattern

Adopt the shape before tuning it. Each of these survived several rounds of "surely we can
simplify this" in the field, and the parts that look like ceremony — the self-pin, the negative
fixtures, the reasons on waivers — are precisely the parts that earned their place by failing
loudly when they were missing.
