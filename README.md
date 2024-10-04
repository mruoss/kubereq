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
    {:kubereq, "~> 0.3.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/kubereq>.

## Usage

This library can used with plan `Req` but the function in this module
provide an easier API to people used to `kubectl` and friends.

### Plain Req

Use `Kubereq.Kubeconfig.Default` to create connection to cluster and
plain `Req.request()` to make the request

```ex
req = Req.new() |> Kubereq.attach()

Req.request!(req,
  api_version: "v1",
  kind: "ServiceAccount",
  operation: :get,
  path_params: [namespace: "default", name: "default"]
)
```

You can pass your own Kubeconfigloader pipeline when attaching:

```ex
req = Req.new() |> Kubereq.attach(kubeconfig: {Kubereq.Kubeconfig.File, path: "/path/to/kubeconfig.yaml"})

Req.request!(req,
  api_version: "v1",
  kind: "ServiceAccount",
  operation: :get,
  path_params: [namespace: "default", name: "default"]
)
```

Prepare a `Req` struct for a specific resource:

```ex
sa_req = Req.new() |> Kubereq.attach(api_version: "v1", kind: "ServiceAccount")

Req.request!(sa_req,  operation: :get, path_params: [namespace: "default", name: "default"])
Req.request!(sa_req,  operation: :list, path_params: [namespace: "default"])
```

### Kubectl API

While this library can attach to any `Req` struct, it is sometimes easier
to prepare `Req` for a specific resource and then use the functions
defined in the `Kubereq` module.

```ex
sa_req = Req.new() |> Kubereq.attach(api_version: "v1", kind: "ServiceAccount")

Kubereq.get(sa_req, "my-namespace", "default")
Kubereq.list(sa_req, "my-namespace")
```

Or use the functions right away, defining the resource through options:

```ex
req = Req.new() |> Kubereq.attach()

Kubereq.get(req, "my-namespace", "default", api_version: "v1", kind: "ServiceAccount")

# get the "status" subresource of the default namespace
Kubereq.get(req, "my-namespace", api_version: "v1", kind: "Namespace", subresource: "status")
```

For resources defined by Kubernetes, the `api_version` can be omitted:

```ex
Req.new()
|> Kubereq.attach(kind: "Namespace")
|> Kubereq.get("my-namespace")
```
