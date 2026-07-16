---
sidebar_position: 8
---

# yaml

Parse YAML text into Lua values — the counterpart to [`res:json()`](http.md#httpresponse) for a cloud-oriented world where Kubernetes manifests, CI configs, and compose files are all YAML. Both functions are synchronous.

## `yaml.parse(text)`

```lua
yaml.parse(text) --> any
```

Parses a single YAML document into a Lua value (mappings become tables, sequences become lists, scalars become strings/numbers/booleans/nil).

**Returns:** the parsed value. Raises on invalid YAML.

```lua
local chart = yaml.parse(fs.read(out:file("Chart.yaml").path))
t:expect(chart.name):equals("widget")
t:expect(chart.version):equals("0.1.0")
```

## `yaml.parse_all(text)`

```lua
yaml.parse_all(text) --> any[]
```

Parses a multi-document YAML stream (`---`-separated — exactly what Kubernetes manifests use) into a list of Lua values.

**Returns:** one value per document; an empty or whitespace-only string yields `{}`. Raises on the first invalid document (the error names its 1-based index).

```lua
local docs = yaml.parse_all(fs.read(root .. "/k8s/manifests.yaml"))
t:expect(#docs):equals(3)
t:expect(docs[1].kind):equals("Deployment")
t:expect(docs[1].spec.template.spec.containers[1].image):contains("widget")
```

A common smoke check is "every rendered manifest at least parses":

```lua
for _, path in ipairs(fs.glob(root, "**/*.yaml")) do
  yaml.parse_all(fs.read(path))   -- raises (fails the test) on invalid YAML
end
```
