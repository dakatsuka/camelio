(** Framework-neutral test helpers for Choku applications. *)

val request :
  ?meth:Choku.Method.t ->
  ?target:string ->
  ?headers:Choku.Headers.t ->
  ?body:Choku.Body.t ->
  unit ->
  Choku.Request.t
(** [request ()] creates a common server request for handler tests.

    Defaults are [GET], [/], empty headers, and an empty body. Validation is
    delegated to {!Choku.Request.make}. *)

val response_body_string : Choku.Response.t -> string
(** [response_body_string response] returns the buffered server response body.
*)

val client_response_body_string : Choku.Client.Response.t -> string
(** [client_response_body_string response] returns the buffered client response
    body. *)

val streaming_body : ?content_length:int -> string -> Choku.Body.t
(** [streaming_body ?content_length bytes] returns a single-consumption
    streaming body backed by [bytes].

    [content_length] defaults to [String.length bytes]. Consumers that require
    the declared length receive Choku's normal streaming-body errors when the
    source ends before [content_length] bytes. *)

val raw_request :
  sw:Eio.Switch.t ->
  net:'a Eio.Net.t ->
  addr:Eio.Net.Sockaddr.stream ->
  string ->
  string
(** [raw_request ~sw ~net ~addr bytes] opens one connection, writes [bytes],
    shuts down the write side, reads until EOF, and returns the raw response. *)

val with_server :
  ?mono_clock:Eio.Time.Mono.ty Eio.Resource.t ->
  ?addr:Eio.Net.Sockaddr.stream ->
  net:'a Eio.Net.t ->
  Choku.Server.t ->
  (sw:Eio.Switch.t -> addr:Eio.Net.Sockaddr.stream -> base_url:string -> 'b) ->
  'b
(** [with_server ~net server fn] binds a loopback listener, starts [server] on
    it, and runs [fn] with the active switch, actual listening address, and
    [http://] base URL.

    [addr] defaults to [Tcp (Eio.Net.Ipaddr.V4.loopback, 0)]. Unix-domain
    listener base URLs are not supported.

    The server is cancelled and the listener is closed when [fn] returns or
    raises. *)
