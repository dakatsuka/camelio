[@@@alert "-internal"]

let request ?(meth = Choku.Method.GET) ?(target = "/")
    ?(headers = Choku.Headers.empty) ?(body = Choku.Body.empty) () =
  Choku.Request.make ~meth ~target ~headers ~body

let response_body_string response =
  response |> Choku.Response.body |> Choku.Body.to_string

let client_response_body_string response =
  response |> Choku.Client.Response.body |> Choku.Body.to_string

type string_source = { bytes : string; limit : int; mutable offset : int }

module String_source = struct
  type t = string_source

  let read_methods = []

  let single_read t buffer =
    let remaining = t.limit - t.offset in
    if remaining = 0 then raise End_of_file;
    let read = min remaining (Cstruct.length buffer) in
    Cstruct.blit_from_string t.bytes t.offset buffer 0 read;
    t.offset <- t.offset + read;
    read
end

let streaming_body ?content_length bytes =
  let source_length =
    match content_length with
    | Some content_length -> min (String.length bytes) (max 0 content_length)
    | None -> String.length bytes
  in
  let content_length =
    match content_length with
    | Some _ as content_length -> content_length
    | None -> Some (String.length bytes)
  in
  let source =
    Eio.Resource.T
      ( { bytes; limit = source_length; offset = 0 },
        Eio.Flow.Pi.source (module String_source) )
  in
  Choku.Body.Internal.streaming ?content_length source

let raw_request ~sw ~net ~addr bytes =
  let flow = Eio.Net.connect ~sw net addr in
  Eio.Flow.copy_string bytes flow;
  Eio.Flow.shutdown flow `Send;
  Eio.Flow.read_all flow

exception Stop_server

let tcp_base_url ip port =
  let host =
    Eio.Net.Ipaddr.fold ip
      ~v4:(fun ip -> Format.asprintf "%a" Eio.Net.Ipaddr.pp ip)
      ~v6:(fun ip -> Format.asprintf "[%a]" Eio.Net.Ipaddr.pp ip)
  in
  Printf.sprintf "http://%s:%d" host port

let base_url_of_addr = function
  | `Tcp (ip, port) -> tcp_base_url ip port
  | `Unix _ -> invalid_arg "Choku_test.with_server requires a TCP listener"

let with_server ?mono_clock ?(addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, 0)) ~net
    server fn =
  let result = ref None in
  let raised = ref None in
  (try
     Eio.Switch.run @@ fun sw ->
     let socket = Eio.Net.listen ~reuse_addr:true ~backlog:128 ~sw net addr in
     let actual_addr = Eio.Net.listening_addr socket in
     let base_url = base_url_of_addr actual_addr in
     Eio.Fiber.fork ~sw (fun () ->
         Choku.Server.run_listener ~sw ?mono_clock ~socket server);
     (try result := Some (fn ~sw ~addr:actual_addr ~base_url)
      with exn -> raised := Some (exn, Printexc.get_raw_backtrace ()));
     Eio.Switch.fail sw Stop_server
   with Stop_server -> ());
  match (!raised, !result) with
  | Some (exn, backtrace), _ -> Printexc.raise_with_backtrace exn backtrace
  | None, Some result -> result
  | None, None -> failwith "Choku_test.with_server callback did not run"
