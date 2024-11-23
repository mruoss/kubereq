# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

<!-- Add your changelog entry to the relevant subsection -->

<!-- ### Added | Changed | Deprecated | Removed | Fixed | Security -->

### ⚠️ Breaking Changes ⚠️

- `Kubereq.watch/3` and `Kubereq.watch_single/4` now also return `t:Kubereq.response/0`.
  The stream which was returned directly before is now accessible through the `:body`
  key of the returned `t:Req.Response.t/0` struct. The `:stream_to` option was removed.

### Chanes

- `Kubereq.wait_until/5` gets by without `Task.async/1`.

### Added

- Streaming for paginated list operation via the `:into` option of `Kubereq.list/3`
  [#46](https://github.com/mruoss/kubereq/pull/46)

<!--------------------- Don't add new entries after this line --------------------->

## 0.3.2 - 2024-11-22

### Added

- Support for websocket connections to `pods/log` and `pods/exec` subresources [#37](https://github.com/mruoss/kubereq/pull/37)

## 0.3.1 - 2024-10-24

### Fixed

- Include resource name in the path for deletion in order to prevent deleting multiple resources [#41](https://github.com/mruoss/kubereq/issues/41), [#42](https://github.com/mruoss/kubereq/pull/42)

### Added

- Add current context's namespace as `:current_namespace` field to Kubeconfig. [#39](https://github.com/mruoss/kubereq/pull/39)
- Add Req option `:context` to switch context ad-hoc. [#39](https://github.com/mruoss/kubereq/pull/39)

## 0.3.0 - 2024-10-04

### ⚠️ Breaking ⚠️

This release comes with a refactored API of the `kubereq` library and will not
work for code using earlier versions of `kubereq`. Migrating should be straight
forward in most cases.

- `Kubereq.new/N` was deprecated and replaced with `Kubereq.attach/1`
- The result of `Kuberq.attach/1` can be used with `Req` functions directly
- Functions in the `Kubereq` modules still provide a nice abstraction over plain
  `Req`. They now forward all `opts` to `Req`.
- `Kubereq.wait_until/5` now takes a Keyword list as fifth argument (was
  `integer` before). To migrate, just turn `timeout` into `timeout: timeout`

## 0.2.1 - 2024-10-03

### Fixed

- Exec auth wrongly assumes cert data to be base64 encoded [#33](https://github.com/mruoss/kubereq/issues/33), [#34](https://github.com/mruoss/kubereq/pull/34)

## 0.2.0 - 2024-09-20

### Changed

- `exec` auth and other steps now return errors instead of raising exceptions. [#30](https://github.com/mruoss/kubereq/pull/30)

## 0.1.8 - 2024-09-14

### Changed

- `Kubereq.Kubeconfig.Stub`: Set server url to context name

## 0.1.7 - 2024-09-12

### Added

- `Kubereq.Kubeconfig.Stub`: A Kubeconfig step used for testing

## 0.1.6 - 2024-08-25

### Fixed

- `Kubereq.Kubeconfig.ServiceAccount`: make server key a binary

## 0.1.5 - 2024-08-24

### Added

- `Kubereq.wait_until/5`: Support returning `{:error, error}` tuple in the callback

## 0.1.4 - 2024-08-21

### Fixed

- `Kubereq.Kubeconfig.File`: Only expand path if not relative to HOME.

## 0.1.3 - 2024-08-19

### Fixed

- Fixed several bugs and docs
- Dependency updates

## 0.1.2 - 2024-06-13

- Dependency updates

## 0.1.1

### Fixed

- License was wrong in `mix.exs`

## Unreleased

<!-- Add your changelog entry to the relevant subsection -->

<!-- ### Added | Changed | Deprecated | Removed | Fixed | Security -->

<!-- No new entries below this line! -->
