# Kubereq

Build Kubernetes API Clients using Req with `kubereq`.

[![Module Version](https://img.shields.io/hexpm/v/kubereq.svg)](https://hex.pm/packages/kubereq)
[![Last Updated](https://img.shields.io/github/last-commit/mruoss/kubereq.svg)](https://github.com/mruoss/kubereq/commits/main)

[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/kubereq/)
[![Total Download](https://img.shields.io/hexpm/dt/kubereq.svg)](https://hex.pm/packages/kubereq)
[![License](https://img.shields.io/hexpm/l/kubereq.svg)](https://github.com/mruoss/kubereq/blob/main/LICENSE)

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

### Loading the Kubernetes Configuration

Before you can connect to the Kubernetes API Server you need to load the
cluster's Kubernetes configuration (Kubeconfig). This library expects you to use
[`kubeconf`](https://github.com/mruoss/kubeconf) to load the configuration.

Once you have loaded the configuration and filled the `%Kubeconf{}` struct, you
can get a `Req` request using `Kubereq.new/2`.

### Building the `Req.Request` struct

`Kubereq.new/2` creates a `%Req.Request{}` struct which allows you to make
requests to the Kubernetes API Server for **a specific resource kind**. It expects
the `kubeconf` as first argument and the `path` to the resource as second
argument. The path should contain placeholders for `:namespace` and `:name`
which are filled once you make a request to a specific resource.
