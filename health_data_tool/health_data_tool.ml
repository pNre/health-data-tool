open Cmdliner

let watch_folder folder output_json =
  Eio_main.run
  @@ fun env ->
  let base_folder = Eio.Path.(env#fs / folder) in
  let export_xml = Eio.Path.(base_folder / "export.xml") in
  Eio.traceln
    "monitoring %s, exporting to %s"
    Eio.Path.(native_exn base_folder)
    Eio.Path.(native_exn export_xml);
  let read_folder () =
    let open Eio.Path in
    let set = String_float_pair_set.empty in
    read_dir base_folder
    |> List.filter (fun file -> Filename.extension file = ".zip")
    |> List.fold_left
         (fun set file ->
           let path = base_folder / file in
           let mtime = (stat ~follow:false path).mtime in
           String_float_pair_set.add (native_exn path, mtime) set)
         set
  in
  let rec monitor_folder tracked_files =
    let files = read_folder () in
    let changed_files = String_float_pair_set.diff files tracked_files in
    (match String_float_pair_set.choose_opt changed_files with
     | Some (file, _) ->
       Eio.traceln "unpacking %s" file;
       (try
          let zip = Zip.open_in file in
          let zip_entry = Zip.find_entry zip "apple_health_export/export.xml" in
          let export_xml = Eio.Path.(native_exn export_xml) in
          Zip.copy_entry_to_file zip zip_entry export_xml;
          Zip.close_in zip;
          Eio.traceln "mapping %s to %s" export_xml output_json;
          Health_data_mapper.export_xml_to_json export_xml output_json;
          Eio.traceln "done"
        with
        | exn -> Eio.traceln "error unpacking %s: %s" file (Printexc.to_string exn))
     | _ -> ());
    Eio.Time.sleep env#clock 5.0;
    monitor_folder files
  in
  monitor_folder (read_folder ())
;;

let convert input_xml output_json =
  Eio_main.run
  @@ fun _ ->
  Eio.traceln "mapping %s to %s" input_xml output_json;
  Health_data_mapper.export_xml_to_json input_xml output_json;
  Eio.traceln "done"
;;

let () =
  let info = Cmd.info "health-data-tool" in
  let string_pos_arg idx ~docv ~doc =
    Arg.(required & pos idx (some string) None & info [] ~docv ~doc)
  in
  let watch_folder_cmd =
    let info = Cmd.info "watch" in
    let folder = string_pos_arg 0 ~docv:"MONITORED_FOLDER" ~doc:"Monitored folder" in
    let output_json = string_pos_arg 1 ~docv:"OUTPUT_JSON" ~doc:"Output JSON file" in
    Cmd.v info Term.(const watch_folder $ folder $ output_json)
  and convert_cmd =
    let info = Cmd.info "convert" in
    let input_xml = string_pos_arg 0 ~docv:"INPUT_XML" ~doc:"HealthKit Export XML" in
    let output_json = string_pos_arg 1 ~docv:"OUTPUT_JSON" ~doc:"Output JSON file" in
    Cmd.v info Term.(const convert $ input_xml $ output_json)
  in
  let cmd_group = Cmd.group info [ watch_folder_cmd; convert_cmd ] in
  exit (Cmd.eval cmd_group)
;;
