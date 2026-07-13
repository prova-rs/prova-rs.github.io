---
sidebar_position: 9
sidebar_label: "Kafka & Pulsar"
---

# Kafka & Pulsar

Twinned thin messaging clients for driving a broker dependency from a test: **produce** a message the app under test should consume, or **consume** messages the app produced and assert on them. Both consumers read from the **earliest offset**, so a produce-then-consume within one test is reliable regardless of ordering. Both modules ship an ephemeral-container recipe, the messaging counterpart to [`db.postgres`](db.md#recipes-dbpostgres--dbmysql).

:::note Plaintext-only in v1
Neither client does TLS/SASL/token auth — they are aimed at localhost brokers and CI containers.
:::

## kafka

### `kafka.connect(brokers)`

```lua
kafka.connect(brokers) --> KafkaClient
```

| Parameter | Type | Description |
|---|---|---|
| `brokers` | `string` | Bootstrap brokers, `"host:port"` |

**Returns:** a `KafkaClient`. Async; it **verifies connectivity** with a metadata fetch, so wrapping it in `prova.retry` is a real readiness gate. Call inside a fixture factory or test body.

### `KafkaClient`

#### `client:produce(topic, message)`

```lua
client:produce(topic, message)
```

Produces a string message to a topic and awaits the broker's delivery ack. Raises on failure.

#### `client:consume(topic, opts)`

```lua
client:consume(topic, opts?) --> string[]
```

Consumes from a topic — a fresh consumer group with `auto.offset.reset=earliest`, so it reads from the start. Collects up to `max` messages arriving within `timeout` and returns them as a list of strings (fewer if the window closes first; running out of time is not an error).

| Option | Type | Description |
|---|---|---|
| `group` | `string?` | Consumer group id (default `"prova"`) |
| `max` | `integer?` | Stop after this many messages (default `10`) |
| `timeout` | `string?` | Collection window (default `"15s"`) |

#### `client:close()`

No-op (the client drops with the handle); present for `ctx:manage` symmetry.

```lua
local mq = prova.fixture("kafka", Scope.File, function(ctx)
  return kafka.container(ctx).client
end)

prova.group("kafka", { requires = { "docker" } }, function(g)
  g:test("produce and consume round-trips messages", function(t)
    local client = t:use(mq)
    client:produce("prova-demo", "hello")
    client:produce("prova-demo", "world")
    local msgs = client:consume("prova-demo", { max = 2, timeout = "20s" })
    t:expect(#msgs):equals(2)
    t:expect(msgs):contains("hello")
  end)
end)
```

### `kafka.container(ctx, opts)`

```lua
kafka.container(ctx, opts?) --> KafkaResource
```

Provisions an ephemeral single-node Kafka (KRaft, image `apache/kafka`) and returns a connected managed client. Requires the [`docker`](docker.md) module at call time — gate with `requires = { "docker" }`.

:::caution Fixed host port
Unlike the other recipes, Kafka uses a **fixed** host port (default `9092`), because Kafka advertises a listener address clients must be able to reach. Only one `kafka.container` can run per host at a time.
:::

| Parameter | Type | Description |
|---|---|---|
| `ctx` | `Context` | The fixture/test context (first argument, required) |
| `opts.image` | `string?` | Full image ref; overrides `tag` |
| `opts.tag` | `string?` | Image tag (default `"3.9.0"`) |
| `opts.port` | `integer?` | Fixed host port (default `9092`) |
| `opts.timeout` | `string?` | Readiness deadline (default `"90s"`) |

**Returns:** a `KafkaResource`: `brokers` (`string`, e.g. `"127.0.0.1:9092"`), `client` (`KafkaClient`, managed), and `container` (the managed [container handle](docker.md#container)).

## pulsar

### `pulsar.connect(url)`

```lua
pulsar.connect(url) --> PulsarClient
```

| Parameter | Type | Description |
|---|---|---|
| `url` | `string` | `pulsar://host:port` |

**Returns:** a `PulsarClient`. Async — call inside a fixture factory or test body.

### `PulsarClient`

#### `client:produce(topic, message)`

```lua
client:produce(topic, message)
```

Produces a string message to a topic and awaits the broker's send receipt (a confirmed send). Raises on failure.

#### `client:consume(topic, opts)`

```lua
client:consume(topic, opts?) --> string[]
```

Consumes from a topic, subscribing at the **earliest** position. Collects up to `max` messages arriving within `timeout`; returns them as a list of strings. Messages are acknowledged as they are collected.

| Option | Type | Description |
|---|---|---|
| `subscription` | `string?` | Subscription name (default `"prova"`) |
| `max` | `integer?` | Stop after this many messages (default `10`) |
| `timeout` | `string?` | Collection window (default `"10s"`) |
| `shared` | `boolean?` | Use a Shared subscription instead of Exclusive |

#### `client:close()`

No-op (the client drops with the handle); present for `ctx:manage` symmetry.

```lua
local mq = prova.fixture("pulsar", Scope.File, function(ctx)
  return pulsar.container(ctx).client
end)

prova.group("pulsar", { requires = { "docker" } }, function(g)
  g:test("produce and consume round-trips messages", function(t)
    local client = t:use(mq)
    client:produce("prova-demo", "hello")
    client:produce("prova-demo", "world")
    local msgs = client:consume("prova-demo", { max = 2, timeout = "15s" })
    t:expect(msgs[1]):equals("hello")
    t:expect(msgs[2]):equals("world")
  end)
end)
```

### `pulsar.container(ctx, opts)`

```lua
pulsar.container(ctx, opts?) --> PulsarResource
```

Provisions an ephemeral Pulsar standalone (image `apachepulsar/pulsar`, command `bin/pulsar standalone`), waits for its "messaging service is ready" log line, connects, and returns a managed client. Requires the [`docker`](docker.md) module at call time.

Pulsar standalone is a heavy image and slow to start (tens of seconds on a cold pull) — the default timeout reflects that.

| Parameter | Type | Description |
|---|---|---|
| `ctx` | `Context` | The fixture/test context (first argument, required) |
| `opts.image` | `string?` | Full image ref; overrides `tag` |
| `opts.tag` | `string?` | Image tag (default `"3.3.1"`) |
| `opts.timeout` | `string?` | Readiness deadline (default `"120s"`) |

**Returns:** a `PulsarResource`: `url` (`string`, e.g. `"pulsar://127.0.0.1:<host_port>"`), `client` (`PulsarClient`, managed), and `container` (the managed [container handle](docker.md#container)).
