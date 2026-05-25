# HTTPS Client

## Status

Accepted

## Context

The current `Choku.Client` opens one TCP connection, writes one HTTP/1.1 request,
reads one fully buffered response, and closes the connection. The HTTPS
milestone should keep that flow and add TLS at the transport boundary.

Relevant local documents:

- [HTTPS Client](../product-specs/https-client.md)
- [Minimal HTTP Client](minimal-http-client.md)
- [Eio TLS References](../references/eio-tls.md)

## Goals

- Add HTTPS without rewriting HTTP/1.1 serialization or response parsing.
- Keep URL parsing, TLS connection setup, and HTTP parsing as separate concerns.
- Verify server certificates by default.
- Keep the public TLS surface small enough to support system roots and test
  fixtures.
- Preserve middleware semantics and cancellation behavior.

## Non-Goals

- TLS server support.
- Client certificates.
- Connection pooling or TLS session resumption.
- HTTP/2, ALPN behavior, redirects, proxying, or CONNECT.

## Proposed Design

Extend `Client.Request.t` with a parsed scheme:

```ocaml
type scheme = Http | Https
```

URL parsing accepts `http://` and `https://`. The scheme determines the default
port and the port omitted from normalized authority.

The transport performs the same request-body buffering check before opening a
connection. It then resolves and connects to `Request.host` and `Request.port`.
For `Http`, it uses the TCP flow directly. For `Https`, it wraps the TCP flow
with `Tls_eio.client_of_flow` using a `Tls.Config.client` derived from the
client TLS policy and the URL host.

After wrapping, the existing `request_wire`, `reader`, and
`read_final_response` functions operate on the selected flow. They should not
need to know whether the flow is plain TCP or TLS.

## TLS Policy

Add `Client.Tls.t` as a small wrapper around a ready authenticator:

- `Tls.system ()` constructs a policy using operating-system CA roots.
- `Tls.ca_file path` constructs a policy using a PEM CA file.
- `Tls.ca_dir path` constructs a policy using a PEM CA directory.

`Client.create` defaults to `Tls.system ()`. If system CA lookup fails, the
client stores the default TLS policy as `(Tls.t, Error.t) result` and returns
that error only when handling an HTTPS request. This keeps existing HTTP-only
clients constructible in environments without a CA bundle. When callers pass an
explicit `~tls`, the value is a successfully loaded policy and no deferred
loading error is stored.

The TLS peer name comes from `Request.host`. The first HTTPS milestone supports
DNS host names only. IPv4 and IPv6 address literals in `https://` URLs are
rejected during URL parsing instead of falling back to insecure verification or
implementing IP-address certificate matching in the first pass. Plain `http://`
URLs keep their existing IPv4 literal support.

TLS handshakes use TLS 1.2 or newer. Choku does not expose custom TLS version or
cipher-suite controls in this milestone.

Choku does not initialize Mirage Crypto RNG implicitly. HTTPS documentation and
examples must show callers initializing the RNG before TLS use with
`Mirage_crypto_rng_unix.use_default ()`.

## Contracts

Public interface additions:

```ocaml
module Client : sig
  module Error : sig
    type t =
      | ...
      | Tls_configuration_failed of string
      | Tls_handshake_failed of exn
  end

  module Request : sig
    type scheme = Http | Https
    val scheme : t -> scheme
  end

  module Tls : sig
    type t
    val system : unit -> (t, Error.t) result
    val ca_file : _ Eio.Path.t -> (t, Error.t) result
    val ca_dir : _ Eio.Path.t -> (t, Error.t) result
  end

  val create :
    ?tls:Tls.t ->
    ?max_response_head_size:int ->
    ?max_response_body_size:int ->
    ?middlewares:Middleware.t list ->
    net:'a Eio.Net.t ->
    unit ->
    t
end
```

The existing `Connection_failed` remains for DNS, TCP, write, read, and
non-cancellation I/O exceptions. TLS setup and handshake exceptions map to TLS
errors.

## Alternatives Considered

- Depend on a full HTTP client such as `cohttp-eio`: rejected because Choku's
  client should keep its own protocol contracts and avoid introducing cohttp.
- Use OpenSSL bindings through `eio-ssl`: deferred because `tls-eio` already
  provides a direct Eio flow abstraction and keeps the dependency pure OCaml.
- Make `Client.create` fail if system CA loading fails: rejected because it
  would make plain HTTP use depend on host CA configuration.

## Third-Party Review

Context-free review identified four pre-implementation issues:

- HTTPS IP-literal peer-name handling was underspecified.
- The default TLS policy storage model conflicted with `Tls.system` returning a
  result.
- Secure TLS protocol-version behavior was unspecified.
- Public `insecure_no_verify` was a production footgun.

The design now rejects HTTPS IP literals, stores default TLS loading errors in
`Client.t`, requires TLS 1.2 or newer, and removes insecure verification from
the public API.

## Validation

- Unit tests for URL scheme/default-port normalization.
- Unit tests for TLS policy error printing and equality.
- Optional network-gated smoke test against a public HTTPS endpoint when
  external network is available.
- `dune build @all`, `dune runtest`, `dune build @fmt`, and `dune build @check`.

## Open Questions

None.
