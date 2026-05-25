open Alcotest

let require_network () =
  match Sys.getenv_opt "CHOKU_RUN_NETWORK_TESTS" with
  | Some "1" -> ()
  | _ -> skip ()

let request_ok ~meth ~url () =
  match Choku.Client.Request.make ~meth ~url () with
  | Ok request -> request
  | Error error ->
      failf "unexpected request error: %a" Choku.Client.Error.pp error

let test_request_defaults () =
  let request = Choku_test.request () in
  check
    (module Choku.Method)
    "method" Choku.Method.GET
    (Choku.Request.meth request);
  check string "target" "/" (Choku.Request.target request);
  check string "path" "/" (Choku.Request.path request);
  check string "body" "" (Choku.Body.to_string (Choku.Request.body request))

let test_response_body_helpers () =
  let server_response = Choku.Response.text "ok\n" in
  let client_response =
    Choku.Client.Response.make
      ~body:(Choku.Body.string "client\n")
      Choku.Status.accepted
  in
  check string "server body" "ok\n"
    (Choku_test.response_body_string server_response);
  check string "client body" "client\n"
    (Choku_test.client_response_body_string client_response)

let test_streaming_body () =
  let body = Choku_test.streaming_body "streamed" in
  check bool "not buffered" false (Choku.Body.is_buffered body);
  check
    (result string (of_pp Choku.Body.pp_error))
    "body" (Ok "streamed")
    (Choku.Body.to_string_limited ~max_size:16 body);
  check_raises "single consumption"
    (Invalid_argument "streaming body has already been consumed") (fun () ->
      ignore (Choku.Body.to_string_limited ~max_size:16 body : _ result))

let test_streaming_body_reports_short_source () =
  let body = Choku_test.streaming_body ~content_length:8 "short" in
  check
    (result string (of_pp Choku.Body.pp_error))
    "body" (Error Choku.Body.Unexpected_end_of_body)
    (Choku.Body.to_string_limited ~max_size:16 body)

let test_streaming_body_caps_source_to_declared_length () =
  let body = Choku_test.streaming_body ~content_length:4 "streamed" in
  let bytes = Choku.Body.with_source body Eio.Flow.read_all in
  check string "source bytes" "stre" bytes

let test_with_server_client_request () =
  require_network ();
  Eio_main.run @@ fun env ->
  let net = Eio.Stdenv.net env in
  let server =
    Choku.Server.create
      ~handler:(fun request ->
        Choku.Response.text (Choku.Request.path request ^ "\n"))
      ()
  in
  Choku_test.with_server ~net server @@ fun ~sw ~addr:_ ~base_url ->
  let client = Choku.Client.create ~net () in
  let request =
    request_ok ~meth:Choku.Method.GET ~url:(base_url ^ "/health") ()
  in
  match Choku.Client.request ~sw client request with
  | Error error ->
      failf "unexpected client error: %a" Choku.Client.Error.pp error
  | Ok response ->
      check string "body" "/health\n"
        (Choku_test.client_response_body_string response)

let test_raw_request () =
  require_network ();
  Eio_main.run @@ fun env ->
  let net = Eio.Stdenv.net env in
  let server =
    Choku.Server.create ~keep_alive:false
      ~handler:(fun _ -> Choku.Response.text "raw\n")
      ()
  in
  Choku_test.with_server ~net server @@ fun ~sw ~addr ~base_url:_ ->
  let response =
    Choku_test.raw_request ~sw ~net ~addr
      "GET / HTTP/1.1\r\nHost: example.test\r\n\r\n"
  in
  check bool "status" true
    (String.starts_with ~prefix:"HTTP/1.1 200 OK" response);
  check bool "body" true (String.ends_with ~suffix:"raw\n" response)

let () =
  run "choku_test"
    [
      ( "helpers",
        [
          test_case "request defaults" `Quick test_request_defaults;
          test_case "response body helpers" `Quick test_response_body_helpers;
          test_case "streaming body" `Quick test_streaming_body;
          test_case "streaming body reports short source" `Quick
            test_streaming_body_reports_short_source;
          test_case "streaming body caps source to declared length" `Quick
            test_streaming_body_caps_source_to_declared_length;
        ] );
      ( "network",
        [
          test_case "with_server client request" `Quick
            test_with_server_client_request;
          test_case "raw request" `Quick test_raw_request;
        ] );
    ]
