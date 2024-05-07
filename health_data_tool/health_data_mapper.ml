let rec json_encode_obj_repr json encode =
  match json with
  | (`String _ | `Float _ | `Null) as lex -> ignore @@ encode (`Lexeme lex)
  | `A elements ->
    ignore @@ encode (`Lexeme `As);
    List.iter (fun el -> json_encode_obj_repr el encode) elements;
    ignore @@ encode (`Lexeme `Ae)
  | `O props ->
    ignore @@ encode (`Lexeme `Os);
    List.iter
      (fun (k, v) ->
        ignore @@ encode (`Lexeme (`Name k));
        json_encode_obj_repr v encode)
      props;
    ignore @@ encode (`Lexeme `Oe)
;;

let float_ts_of_date_string ds =
  let parsed = ExtUnix.All.strptime "%Y-%m-%d %H:%M:%S %z" ds in
  fst @@ Unix.mktime parsed
;;

let float_assoc_opt k kv =
  List.assoc_opt k kv |> Option.map Float.of_string |> Option.map (fun f -> `Float f)
;;

let opt_prop name value = Option.map (fun value -> name, value) value

let rec parse_records input ~metadata ~els encode =
  if Xmlm.eoi input
  then ()
  else (
    match Xmlm.input input, els with
    | `El_start ((_, "Record"), attributes), _ ->
      let kv = List.map (fun ((_, key), value) -> key, value) attributes in
      let typ = List.assoc "type" kv in
      let value = List.assoc "value" kv in
      let creationDate = float_ts_of_date_string @@ List.assoc "creationDate" kv in
      let startDate = float_ts_of_date_string @@ List.assoc "startDate" kv in
      let endDate = float_ts_of_date_string @@ List.assoc "endDate" kv in
      let record =
        [ "type", `String typ
        ; "value", `String value
        ; "creation", `Float creationDate
        ; "start", `Float startDate
        ; "end", `Float endDate
        ]
      in
      parse_records input ~metadata ~els:(`Record record :: els) encode
    | `El_start ((_, "MetadataEntry"), attributes), `Record _ :: _
    | `El_start ((_, "MetadataEntry"), attributes), `Metadata :: _ ->
      let kv = List.map (fun ((_, key), value) -> key, value) attributes in
      let key = List.assoc "key" kv in
      let value = List.assoc "value" kv in
      let metadata = `O [ "key", `String key; "value", `String value ] :: metadata in
      parse_records input ~metadata ~els:(`Metadata :: els) encode
    | `El_start _, _ -> parse_records input ~metadata ~els:(`Ignored :: els) encode
    | `El_end, `Record record :: _ ->
      json_encode_obj_repr (`O (("metadata", `A metadata) :: record)) encode;
      parse_records input ~metadata:[] ~els:(List.tl els) encode
    | `El_end, _ -> parse_records input ~metadata ~els:(List.tl els) encode
    | `Data _, _ -> parse_records input ~metadata ~els encode
    | `Dtd _, _ -> parse_records input ~metadata ~els encode)
;;

let parse_records input encode = parse_records input ~metadata:[] ~els:[] encode

let rec parse_workouts input ~statistics ~events ~els encode =
  if Xmlm.eoi input
  then ()
  else (
    match Xmlm.input input, els with
    | `El_start ((_, "Workout"), attributes), _ ->
      let kv = List.map (fun ((_, key), value) -> key, value) attributes in
      let typ = List.assoc "workoutActivityType" kv in
      let duration = Float.of_string @@ List.assoc "duration" kv in
      let creationDate = float_ts_of_date_string @@ List.assoc "creationDate" kv in
      let startDate = float_ts_of_date_string @@ List.assoc "startDate" kv in
      let endDate = float_ts_of_date_string @@ List.assoc "endDate" kv in
      let workout =
        [ "type", `String typ
        ; "duration", `Float duration
        ; "creation", `Float creationDate
        ; "start", `Float startDate
        ; "end", `Float endDate
        ]
      in
      parse_workouts input ~statistics ~events ~els:(`Workout workout :: els) encode
    | `El_start ((_, "WorkoutStatistics"), attributes), _ ->
      let kv = List.map (fun ((_, key), value) -> key, value) attributes in
      let typ = List.assoc "type" kv in
      let sum = float_assoc_opt "sum" kv in
      let average = float_assoc_opt "average" kv in
      let minimum = float_assoc_opt "minimum" kv in
      let maximum = float_assoc_opt "maximum" kv in
      let unit = List.assoc_opt "unit" kv |> Option.map (fun f -> `String f) in
      let statistics =
        `O
          (List.filter_map
             Fun.id
             [ Some ("type", `String typ)
             ; opt_prop "sum" sum
             ; opt_prop "average" average
             ; opt_prop "minimum" minimum
             ; opt_prop "maximum" maximum
             ; opt_prop "unit" unit
             ])
        :: statistics
      in
      parse_workouts input ~statistics ~events ~els:(`Statistics :: els) encode
    | `El_start ((_, "WorkoutEvent"), attributes), _ ->
      let kv = List.map (fun ((_, key), value) -> key, value) attributes in
      let typ = List.assoc "type" kv in
      let date = float_ts_of_date_string @@ List.assoc "date" kv in
      let duration = float_assoc_opt "duration" kv in
      let durationUnit =
        List.assoc_opt "durationUnit" kv |> Option.map (fun f -> `String f)
      in
      let events =
        `O
          (List.filter_map
             Fun.id
             [ Some ("type", `String typ)
             ; Some ("date", `Float date)
             ; opt_prop "duration" duration
             ; opt_prop "durationUnit" durationUnit
             ])
        :: events
      in
      parse_workouts input ~statistics ~events ~els:(`Event :: els) encode
    | `El_start _, _ ->
      parse_workouts input ~statistics ~events ~els:(`Ignored :: els) encode
    | `El_end, `Workout workout :: _ ->
      let workout =
        `O (List.append [ "events", `A events; "statistics", `A statistics ] workout)
      in
      json_encode_obj_repr workout encode;
      parse_workouts input ~statistics:[] ~events:[] ~els:(List.tl els) encode
    | `El_end, _ -> parse_workouts input ~statistics ~events ~els:(List.tl els) encode
    | `Data _, _ | `Dtd _, _ -> parse_workouts input ~statistics ~events ~els encode)
;;

let parse_workouts input encode =
  parse_workouts input ~statistics:[] ~events:[] ~els:[] encode
;;

let export_xml_to_json input_xml output_json =
  let out_channel = Stdlib.open_out output_json in
  let output = Jsonm.encoder (`Channel out_channel) in
  let encode = Jsonm.encode output in
  ignore @@ encode (`Lexeme `Os);
  ignore @@ encode (`Lexeme (`Name "records"));
  let input = Xmlm.make_input (`Channel (Stdlib.open_in input_xml)) in
  ignore @@ encode (`Lexeme `As);
  parse_records input encode;
  ignore @@ encode (`Lexeme `Ae);
  ignore @@ encode (`Lexeme (`Name "workouts"));
  let input = Xmlm.make_input (`Channel (Stdlib.open_in input_xml)) in
  ignore @@ encode (`Lexeme `As);
  parse_workouts input encode;
  ignore @@ encode (`Lexeme `Ae);
  ignore @@ encode (`Lexeme `Oe);
  ignore @@ encode `End;
  Stdlib.close_out out_channel
;;
