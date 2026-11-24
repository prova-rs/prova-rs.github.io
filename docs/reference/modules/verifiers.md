---
sidebar_position: 9
sidebar_label: "Verifiers & Measurements"
---

# Verifiers & Measurements

The namespaces a [deputed conduct](../../quality/deputed-verifiers.md) hands its results to:
`junit` and `sarif` adopt verdicts, `measure` holds numbers to [ratchets](../../quality/ratchets.md),
`report` keeps artifacts, and `date` is the calendar helper reminder conditions use. All are globals;
no `require` is needed. Each `load` and `ingest` is a no-op on the run's account outside a recorded
run, so probing them with `prova eval` changes nothing.

## `junit`

| Function | Does |
|---|---|
| `junit.verify(t, { results, run?, cwd? })` | Run `run` tolerantly (if given), load `results` (a path or glob), ingest it, and fail with the deputed cases' own names on any failed or errored case. Fails on zero parsed cases. With `run`, a results file older than the run is refused. Returns the report. |
| `junit.load(pattern, { cwd? })` | Parse JUnit XML files into a report without recording anything. |
| `junit.ingest(report)` | File a loaded report's cases into the run's deputed account. Returns the count. |

A report is `{ total, passed, failed, errors, skipped, flaky, files, cases }`. Each case is
`{ suite, name, outcome, message?, time_ms?, file }`, where `outcome` is `"passed"`, `"failed"`,
`"error"` or `"skipped"`, and `file` is the artifact the verdict was read from.

## `sarif`

| Function | Does |
|---|---|
| `sarif.verify(t, { results, run?, cwd?, level?, max? })` | Run `run` tolerantly, load and ingest the SARIF at `results`, and fail when more than `max` (default 0) findings sit at or above `level` (`"note"`, `"warning"`, `"error"`; default `"error"`). Zero findings is a clean pass. Returns the report. |
| `sarif.load(pattern, { cwd? })` | Parse SARIF files into a report without recording anything. |
| `sarif.ingest(report)` | File a loaded report's findings into the run's deputed account. |

Each finding carries the tool, `rule`, `level`, `message`, and its first location (`uri`, `line`).
A result with no `level` reads as `"warning"`, SARIF's own default.

## `measure`

| Function | Does |
|---|---|
| `measure.ratchet(t, name, value, { set?, direction? })` | Record `value` and assert it against `.prova/baselines/<set>.json`. Fails on a regression past the floor (and its `tolerance`), on a missing baseline, on a reached `goal`, and on a missed `deadline`. |
| `measure.record(name, value, { set?, direction? })` | Record `value` into the run's measurements without asserting. Returns the value. |

`set` defaults to `"default"`; `direction` is `"lower_is_better"` (default) or `"higher_is_better"`.
A baseline metric is `{ value, direction, tolerance?, goal?, deadline? }`. Only
`prova --update-baseline` writes a baseline, and it only tightens.

## `report`

`report.publish{ name, summary, forms, explains? }` copies a conduct's artifact into
`.prova/var/reports/<name>/` and makes it addressable by `prova reports <name>`.

| Field | Meaning |
|---|---|
| `name` | required: the stable address |
| `summary` | required: one line saying what the artifact shows |
| `forms` | required: renderings of the same fact, such as `{ json = path, html = path }` |
| `explains` | the measurement name (or names) this artifact is evidence for |

## `date`

Dates are `"YYYY-MM-DD"` strings, optionally with `" HH:MM:SS"`, or unix-seconds numbers; every
function accepts either. Times are local.

| Function | Returns |
|---|---|
| `date.now()` | the current time, unix seconds |
| `date.parse(s)` | unix seconds for a date string |
| `date.format(ts?, fmt?)` | `os.date` formatting, `"%Y-%m-%d"` by default |
| `date.diff_days(a, b)` | whole days from `a` to `b`, floored |
| `date.days_since(v)` | whole days from `v` until now |
| `date.days_until(v)` | whole days from now until `v` |
| `date.past(v)` | `true` once `v` is in the past |

```lua
prova.remind("backlog-drawdown", { when = function(a)
  for _, o in ipairs(a.specs) do
    if o.kind == "backlog" and o.recorded and date.days_since(o.recorded) > 30 then
      return o.address .. " has waited " .. date.days_since(o.recorded) .. " days"
    end
  end
end }, "promote, remove, or reschedule it")
```
