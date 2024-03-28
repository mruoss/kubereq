# Kubereq

Used by [`kubegen`](https://github.com/mruoss/kubegen) to build Resource based
Kubernetes API clients using Req with `kubereq`.

[![Module Version](https://img.shields.io/hexpm/v/kubereq.svg)](https://hex.pm/packages/kubereq)
[![Last Updated](https://img.shields.io/github/last-commit/mruoss/kubereq.svg)](https://github.com/mruoss/kubereq/commits/main)

[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/kubereq/)
[![Total Download](https://img.shields.io/hexpm/dt/kubereq.svg)](https://hex.pm/packages/kubereq)
[![License](https://img.shields.io/hexpm/l/kubereq.svg)](https://github.com/mruoss/kubereq/blob/main/LICENSE.md)

While this library can be used directly, it is easier to let
[`kubegen`](https://github.com/mruoss/kubegen) generate the API client modules
for you. The resulting clients are then using `kubereq` to get the prepared
`Req.Request` struct and make the requests to the Kubernetes API Server.

## Installation

The package can be installed by adding `kubereq` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:kubereq, "~> 0.1.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/kubereq>.

## Usage with [`kubegen`](https://github.com/mruoss/kubegen)

Unless you want to build your clients yourself, you can use
[`kubegen`](https://github.com/mruoss/kubegen) to generate clients for each
resource kind you need. Check out [`kubegen`](https://github.com/mruoss/kubegen).

## Build your own clients

### Define how to load the Kubernetes Config

In order to get started quickly, you can just use the default pipeline
(`Kubereq.Kubeconfig.Default`) which tries to load the Kubernetes configuration
one-by-one from well-known sources.

If you need more sophisticated rules, you can build your own Kubeconfig loader
pipeline by creating a module `use`-ing [`Pluggable.StepBuilder`](https://hexdocs.pm/pluggable/Pluggable.StepBuilder.html)
and adding `Pluggable` steps defined by this module. The mechanism is exactly
the same as you know from the `Plug` library.

In fact, the default pipeline mentioned above is implemented defining a set of
steps.

```ex
defmodule Kubereq.Kubeconfig.Default do
  use Pluggable.StepBuilder

  step Kubereq.Kubeconfig.ENV
  step Kubereq.Kubeconfig.File, path: ".kube/config", relative_to_home?: true
  step Kubereq.Kubeconfig.ServiceAccount
end
```

### Load the Kubernetes Config

With the pipeline defined or implemented, you can now call
`Kubereq.Kubeconfig.load/1` to load the config:

```ex
Kubereq.Kubeconfig.load(Kubereq.Kubeconfig.Default)
```

If your pipelines requires options, you can pass a tuple to
`Kubereq.Kubeconfig.load/1`:

```ex
Kubereq.Kubeconfig.load({Kubereq.Kubeconfig.File, path: ".kube/config", relative_to_home?: true})
```

Instead of creating a new module, you can also pass a list of steps to
`Kubereq.Kubeconfig.load/1`:

```ex
Kubereq.Kubeconfig.load([
  Kubereq.Kubeconfig.ENV,
  {Kubereq.Kubeconfig.File, path: ".kube/config", relative_to_home?: true},
  Kubereq.Kubeconfig.ServiceAccount
])
```

### Building the `Req.Request` struct

Once you have loaded the, you can pass it to `Kubereq.new/2` to get a
`%Req.Request{}` struct which is prepared to make requests to the Kubernetes
API Server for **a specific resource kind**. It expects the `kubeconf` as first
argument and the `path` to the resource as second argument. The path should
contain placeholders for `:namespace` and `:name` which are filled once you make
a request to a specific resource.

The following example builds a `%Req.Request{}` which acts as client for running
operations on `ConfigMaps`:

```ex
kubeconfig = Kubereq.Kubeconfig.load(Kubereq.Kubeconfig.Default)
req = Kubereq.new(kubeconfig, "api/v1/namespaces/:namespace/configmaps/:name")
```

### Running Operations

With the `req` built above, you can now use the other functions defined by
`Kubereq` to run operations - in this example on `ConfigMaps`.

```ex
kubeconfig = Kubereq.Kubeconfig.load(Kubereq.Kubeconfig.Default)
req = Kubereq.new(kubeconfig, "api/v1/namespaces/:namespace/configmaps/:name")

{:ok, resp} = Kubereq.get(req, "my-namespace", "my-config-map")
```

`resp` is a `Req.Response.t()` and you can check for `req.status` and get
`req.body` etc.
