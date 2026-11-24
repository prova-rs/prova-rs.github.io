#!/usr/bin/env python3
"""Generate docs/reference/api.md from `prova introspect`.

The binary's own API surface (parsed from its LuaCATS stubs) is the source of truth, so this page
cannot drift from editor completion. Run it after upgrading the prova the site describes:

    python3 scripts/reference_from_introspect.py [--release-stubs DIR --release vX.Y.Z]

`--release-stubs DIR` keeps only entries whose name appears in that directory's *.lua stubs: use
it when the local binary is a dev build ahead of the release the docs describe.
"""
import argparse, collections, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "reference" / "api.md"

def entries(text):
    out, cur = [], None
    for line in text.splitlines():
        if line.startswith("      ") and cur is not None:
            cur["summary"] = (cur["summary"] + " " + line.strip()).strip()
        elif line.startswith("  ") and not line.startswith("   ") and line.strip():
            cur = {"sig": line.strip(), "summary": ""}
            out.append(cur)
    return out

def key(sig):
    m = re.match(r"([A-Za-z_][\w]*)([.:])([A-Za-z_][\w]*)", sig)
    return (m.group(1), m.group(2), m.group(3)) if m else (sig.split("(")[0], "", "")

def in_release(sig, stubs):
    owner, sep, name = key(sig)
    if not sep:
        return owner in stubs
    return f"{owner}{sep}{name}" in stubs or re.search(rf"\b{re.escape(owner)}\b", stubs) and \
        re.search(rf"[.:]{re.escape(name)}\b", stubs) is not None

# Stub text known to lag the runtime, as of prova v0.30.12. Each row is a defect in prova's LuaCATS
# stubs (library/prova.lua) to fix upstream; when a row stops matching, the stub was fixed: delete
# the row. The generator prints every correction it applies.
CORRECTIONS = [
    ("spec?: string", "promises?: string"),
    ("prova.TestOpts.spec", "prova.TestOpts.promises"),
    ("`prova learn specs`", "`prova learn promises`"),
    ("`prova falsify`", "`prova tests falsify`"),
    ("Open spec (red body)", "Open promise (red body)"),
    ("never together with `spec`", "never together with `promises`"),
    ("a spec's reason", "a promise's reason"),
]

def correct(text):
    for old, new in CORRECTIONS:
        if old in text:
            print(f"corrected stale stub text: {old!r} -> {new!r}", file=sys.stderr)
            text = text.replace(old, new)
    return text

def esc(s):
    return s.replace("|", "\\|").replace("<", "&lt;").replace("{", "&#123;").replace("}", "&#125;")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--release-stubs")
    ap.add_argument("--release", help="the release the stubs belong to, e.g. v0.30.12")
    args = ap.parse_args()
    raw = subprocess.run(["prova", "introspect"], capture_output=True, text=True, check=True).stdout
    items = entries(correct(raw))
    if args.release_stubs:
        stubs = "\n".join(p.read_text() for p in pathlib.Path(args.release_stubs).rglob("*.lua"))
        dropped = [i["sig"] for i in items if not in_release(i["sig"], stubs)]
        items = [i for i in items if in_release(i["sig"], stubs)]
        for d in dropped:
            print("not in the release stubs, left out:", d.split("(")[0].split("{")[0], file=sys.stderr)
    namespaces = collections.defaultdict(list)
    types = collections.defaultdict(list)
    for i in items:
        owner, sep, name = key(i["sig"])
        if sep == ":" or owner[:1].isupper() or (owner == "prova" and name[:1].isupper()):
            types[name if owner == "prova" else owner].append(i)
        elif sep == ".":
            namespaces[owner].append(i)
        else:
            types[owner].append(i)
    version = args.release or subprocess.run(["prova", "--version"], capture_output=True, text=True).stdout.strip()
    if args.release_stubs and not args.release:
        sys.exit("--release-stubs needs --release: name the release the page describes")
    lines = [
        "---", "sidebar_position: 2.5", 'sidebar_label: "API Index"', "---", "",
        "# API Index", "",
        "Every function, method and type the `prova` binary reports, with its signature and summary.",
        "This page is generated from `prova introspect` by `scripts/reference_from_introspect.py`;",
        "do not edit it by hand. The module pages ([Modules](./modules/index.md)) and the",
        "[Lua API](./lua-api/index.md) explain the important ones in depth; namespaces the stubs do",
        "not describe yet are on [Verifiers & Measurements](./modules/verifiers.md). Where a stub lags",
        "the runtime, the [Lua API](./lua-api/prova.md) page is authoritative.", "",
        f"Generated for prova {version.split('+')[0].removeprefix('prova ')} (`prova introspect` in your own shell always",
        "matches the binary you run).", "",
    ]
    def block(title, group):
        lines.extend([f"### `{title}`", ""])
        for i in sorted(group, key=lambda i: i["sig"]):
            lines.append("```lua")
            lines.append(i["sig"])
            lines.append("```")
            lines.append("")
            if i["summary"]:
                lines.append(esc(i["summary"]))
                lines.append("")
    lines.extend(["## Namespaces", ""])
    for ns in sorted(namespaces):
        block(ns, namespaces[ns])
    lines.extend(["## Types and methods", ""])
    for t in sorted(types):
        block(t, types[t])
    OUT.write_text("\n".join(lines).rstrip() + "\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {sum(map(len, namespaces.values()))} functions, "
          f"{sum(map(len, types.values()))} types and methods", file=sys.stderr)

main()
