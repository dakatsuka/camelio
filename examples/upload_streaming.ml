let response_for_multipart_error error =
  Camelio.Response.text ~status:Camelio.Status.bad_request
    (Format.asprintf "%a\n" Camelio.Multipart.pp_error error)

let basename path =
  match Eio.Path.split path with None -> "" | Some (_, basename) -> basename

let drain source =
  let scratch = Cstruct.create 8192 in
  let rec loop () =
    match Eio.Flow.single_read source scratch with
    | exception End_of_file -> ()
    | _ -> loop ()
  in
  loop ()

let upload ~upload_dir ~random request =
  let files = ref [] in
  match
    Camelio.Multipart.Streaming.iter_request request
      ~on_part:(fun part source ->
        match Camelio.Multipart.Streaming.filename part with
        | None -> drain source
        | Some filename ->
            let saved =
              Camelio.Multipart.Tempfile.save_source ~dir:upload_dir ~random
                ~original_filename:filename source
            in
            let filename =
              Camelio.Multipart.Tempfile.display_filename saved
              |> Option.value ~default:"upload"
            in
            files :=
              ( filename,
                Camelio.Multipart.Tempfile.size saved,
                basename (Camelio.Multipart.Tempfile.path saved) )
              :: !files)
  with
  | Error error -> response_for_multipart_error error
  | Ok () ->
      let lines =
        !files |> List.rev
        |> List.map (fun (filename, bytes, storage_name) ->
            Printf.sprintf "%s %d bytes stored as %s\n" filename bytes
              storage_name)
        |> String.concat ""
      in
      Camelio.Response.text lines

let handler ~upload_dir ~random request =
  match Camelio.Request.(meth request, path request) with
  | Camelio.Method.POST, "/upload" -> upload ~upload_dir ~random request
  | Camelio.Method.GET, "/health" -> Camelio.Response.text "ok\n"
  | _ -> Camelio.Response.text ~status:Camelio.Status.not_found "not found\n"

let () =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
  let net = Eio.Stdenv.net env in
  let upload_dir = Eio.Path.(Eio.Stdenv.cwd env / "_camelio_uploads") in
  Eio.Path.mkdirs ~exists_ok:true ~perm:0o700 upload_dir;
  let random = Eio.Stdenv.secure_random env in
  let addr = `Tcp (Eio.Net.Ipaddr.V4.loopback, 8080) in
  let server =
    Camelio.Server.create ~request_body_mode:Camelio.Server.Streaming
      ~handler:(handler ~upload_dir ~random)
      ()
  in
  Camelio.Server.run ~sw ~net ~addr server
