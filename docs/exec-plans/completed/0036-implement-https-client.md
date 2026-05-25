# Implement HTTPS Client

## Status

Completed

## Objective

Add `https://` support to `Choku.Client` using Eio-native TLS with certificate
verification by default.

## Context

- [HTTPS Client Spec](../../product-specs/https-client.md)
- [HTTPS Client Design](../../design-docs/https-client.md)
- [Minimal HTTP Client Spec](../../product-specs/minimal-http-client.md)
- [Eio TLS References](../../references/eio-tls.md)

## Clarifications

- The user agreed to the proposed approach: `tls-eio`/`ocaml-tls`,
  certificate verification by default, SNI from the URL host, and a focused
  first HTTPS milestone without pooling, redirects, proxying, ALPN, or HTTP/2.

## Contract First

- Add `Client.Request.scheme`.
- Add `Client.Tls` with system CA, CA file, and CA directory policy
  constructors.
- Add TLS configuration and handshake errors to `Client.Error`.
- Add optional `~tls` configuration to `Client.create`.

## Steps

- [x] Explore: inspect existing code, specs, design docs, and tests.
- [x] Design review: request context-free third-party review and incorporate
      feedback.
- [x] Red: write failing behavior-focused tests for HTTPS URL parsing and TLS
      transport behavior.
- [x] Green: implement the smallest change that satisfies the tests.
- [x] Refactor: improve structure while keeping tests green.
- [x] Static checks: run formatters and static analysis tools, then fix
      findings.
- [x] Code review: request context-free third-party review after
      implementation.
- [x] Re-review: fix review findings and repeat review until it passes.

## Decisions

- Keep HTTP/1.1 parsing and serialization scheme-agnostic by wrapping the flow
  before the existing transport writes the request.
- Store default TLS policy creation errors in the client and return them only
  for HTTPS requests, so HTTP-only use remains independent of host CA setup.
- Reject IP literals for `https://` in the first milestone rather than
  weakening certificate verification or adding IP-address verification paths.
- Require TLS 1.2 or newer.
- Do not expose an insecure no-verification TLS policy in the public API.
- Treat numeric HTTPS host forms such as `0x7f000001` as unsupported IP
  literals, not DNS names.
- Re-raise Eio cancellation from TLS CA file and directory loading.

## Verification

- `dune build @fmt`
- `dune exec test/test_client.exe`
- `CHOKU_RUN_NETWORK_TESTS=1 dune exec test/test_client.exe`
- `dune build @all`
- `dune runtest`
- `dune build @check`
- `dune build @install`
- `opam lint choku.opam`

Code review found two medium issues that were fixed:

- Numeric IP address forms in HTTPS URLs were not rejected.
- Eio cancellation during CA loading was converted to a TLS configuration
  error.

It also identified deterministic local TLS tests for custom CA success,
hostname mismatch, and SNI as a remaining coverage improvement.

## Completion Notes

- `Choku.Client` now accepts `https://` URLs with default port 443.
- HTTPS transport wraps the TCP flow with `Tls_eio.client_of_flow` and uses TLS
  1.2 or newer.
- Default HTTPS verification uses system CA roots via `ca-certs`.
- `Client.Tls.ca_file` and `Client.Tls.ca_dir` support custom trust anchors.
- HTTPS host validation rejects IP literals and IP-like numeric forms in the
  first milestone.
- Follow-up: add local TLS fixture tests for custom CA success, hostname
  mismatch rejection, and SNI derived from URL host rather than `Host` headers.

## Commit

`feat: support HTTPS client requests`
