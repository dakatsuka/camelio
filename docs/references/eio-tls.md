# Eio TLS References

## Source

- URL: https://opam.ocaml.org/packages/tls-eio/
- URL: https://ocaml.org/p/tls-eio/latest/src/tls-eio/tls_eio.ml.html
- URL: https://ocaml.org/p/tls/latest/tls/Tls/Config/index.html
- URL: https://opam.ocaml.org/packages/ca-certs/
- URL: https://opam.ocaml.org/packages/mirage-crypto-rng/
- Accessed: 2026-05-25

## Summary

`tls-eio` provides Eio integration for the pure OCaml TLS stack. Its client
constructor wraps an existing `Eio.Flow.two_way` TCP flow with a TLS flow after
performing the client handshake. `Tls.Config.client` requires an
`X509.Authenticator.t` and supports peer name and ALPN configuration.

`ca-certs` detects root CA certificates from the operating system so they can be
used by `ocaml-tls` for server authentication.

`tls-eio` requires a seeded Mirage Crypto RNG while TLS is in use. Current
`mirage-crypto-rng-eio` APIs are deprecated upstream in favor of
`Mirage_crypto_rng_unix.use_default ()`.

## Implications

Choku should implement HTTPS by keeping the existing HTTP/1.1 serializer and
parser unchanged, opening TCP as it does today, and wrapping the TCP flow in
`Tls_eio.client_of_flow` for `https://` requests.

HTTPS support must include certificate verification by default. Test-only or
debug-only insecure verification should be explicit and should not be the
default.

The first HTTPS milestone should document the RNG requirement and keep TLS
configuration small: system CA roots, optional CA file or directory, SNI based
on the URL host, and no HTTP/2 or ALPN behavior.
