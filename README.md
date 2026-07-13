# Site prova-rs.github.io

Documentation site for [Prova](https://github.com/prova-rs/prova), built with
[Docusaurus](https://docusaurus.io/).

## Install

```bash
pnpm install
```

The included `pnpm-workspace.yaml` pre-approves the install scripts Docusaurus
needs — pnpm 10+ blocks dependency build scripts by default. Commit
`pnpm-lock.yaml`; do not add a `package-lock.json`.

## Local Development

```bash
pnpm start
```

Starts a local dev server at http://localhost:3000 with hot reload.

## Build

```bash
pnpm build
```

Generates static content into the `build/` directory.

## Typecheck

```bash
pnpm typecheck
```

## Deploy

Configured for GitHub Pages at `https://prova-rs.github.io/` (root domain).
Push to `main` — the Actions workflow builds and publishes automatically.
