(** Server-side HTTP cookie helpers. *)

type same_site =
  | Strict
  | Lax
  | No_restriction
      (** SameSite attribute value. [No_restriction] serializes as
          [SameSite=None]. *)

val get : string -> Request.t -> string option
(** [get name request] returns the first cookie value named [name], if present.

    Cookie names are case-sensitive. Malformed cookie pairs in the request are
    ignored. *)

val get_all : string -> Request.t -> string list
(** [get_all name request] returns all cookie values named [name] in request
    header order and cookie-pair order.

    Cookie names are case-sensitive. Malformed cookie pairs in the request are
    ignored. *)

val get_unique : string -> Request.t -> string option
(** [get_unique name request] returns [Some value] when exactly one cookie named
    [name] is present, and [None] when no matching cookie or multiple matching
    cookies are present.

    Prefer [get_unique] or explicit [get_all] duplicate handling for
    security-sensitive cookies such as authentication or session cookies.
    Duplicate cookie names can appear in cookie tossing and session fixation
    scenarios, so [get] should be used for such cookies only when first-value
    semantics are intentional. *)

val set :
  ?path:string ->
  ?domain:string ->
  ?max_age:int ->
  ?secure:bool ->
  ?http_only:bool ->
  ?same_site:same_site ->
  string ->
  string ->
  Response.t ->
  Response.t
(** [set ?path ?domain ?max_age ?secure ?http_only ?same_site name value
     response] appends one [Set-Cookie] header to [response].

    [same_site:No_restriction] serializes as [SameSite=None] and requires
    [secure:true].

    Authentication and session cookies should generally set [secure:true],
    [http_only:true], and an explicit [same_site] value.

    @raise Invalid_argument
      if [name], [value], or an attribute value cannot be safely serialized. *)

val delete :
  ?path:string -> ?domain:string -> string -> Response.t -> Response.t
(** [delete ?path ?domain name response] appends an expired [Set-Cookie] header
    for [name].

    The deletion header includes [Max-Age=0] and
    [Expires=Thu, 01 Jan 1970 00:00:00 GMT].

    @raise Invalid_argument
      if [name] or an attribute value cannot be safely serialized. *)
