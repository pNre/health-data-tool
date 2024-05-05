module StringFloatPair = struct
  type t = string * float

  let compare (x0, y0) (x1, y1) =
    match Stdlib.compare x0 x1 with
    | 0 -> Stdlib.compare y0 y1
    | c -> c
  ;;
end

include Set.Make (StringFloatPair)
