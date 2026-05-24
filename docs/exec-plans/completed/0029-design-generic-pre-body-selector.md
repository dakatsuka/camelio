# Design Generic Pre-Body Selector

## Status

Completed

## Objective

Design a generic public API for choosing buffered or streaming request-body
delivery after request-head parsing and before request-body reads, without
requiring `Router.t`.

## Context

- [Generic Pre-Body Selector](../../product-specs/generic-pre-body-selector.md)
- [Generic Pre-Body Selector Design](../../design-docs/generic-pre-body-selector.md)
- [Route-Level Body Mode](../../design-docs/route-level-body-mode.md)
- [Streaming Request Bodies](../../design-docs/streaming-request-bodies.md)
- [Minimal Server API](../../product-specs/minimal-server-api.md)

## Clarifications

- This milestone is design-only.
- Keep `Server.create` and `Server.create_router` behavior unchanged.
- Do not implement per-route limits or timeout policies here.

## Contract First

- Define a stable public `Request_head.t`.
- Define a clear selector-based server constructor.
- Define selector timing, exception, middleware, and `Server.handle` semantics.
- Document the required `Choku.Request_head` public facade export.

## Steps

- [x] Explore: inspect route-level body mode, server internals, public request
      APIs, and future-work notes.
- [x] Draft: add product spec and design doc.
- [x] Design review: request context-free third-party review and incorporate
      feedback.
- [x] Revise: update docs based on review.
- [x] Static checks: run documentation-safe formatting/build checks.

## Decisions

- Use a separate `Server.create_with_request_body_selector` constructor rather
  than adding another optional argument to `Server.create`.
- Expose `Request_head.t` as a shared HTTP value rather than exposing
  `Http1.request_head`.
- Keep router-specific body-mode selection as the preferred router API.
- Implement selector exceptions through an explicit internal result path so
  non-cancellation exceptions can produce 500/close before body reads.
- Export `Request_head` from `Choku`.

## Verification

Passed:

- `dune build @fmt`
- `dune runtest`
- `dune build @all`
- `dune build @check`
- `dune build @install`
- `opam lint choku.opam`

## Completion Notes

Designed a generic pre-body request body-mode selector around a public
`Request_head.t` and a separate `Server.create_with_request_body_selector`
constructor. The design keeps `Server.create` and `Server.create_router`
unchanged, preserves router-owned route-level body mode, and specifies selector
timing, exception, middleware, `Server.handle`, cancellation, and public facade
semantics.

Design review required an explicit internal result path for selector exceptions,
HEAD body suppression for selector failures, `Choku.Request_head` facade export,
and additional validation for malformed request precedence and keep-alive close.
The revised design passed re-review.

## Commit

`docs: design generic pre-body selector`
