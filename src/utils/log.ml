(* SPDX-License-Identifier: AGPL-3.0-or-later *)
(* Copyright © 2021-2024 OCamlPro *)
(* Written by the Owi programmers *)

let debug_on = ref false

let profiling_on = ref false

let debug0 t : unit =
  if !debug_on then begin
    Fmt.epr t;
    Fmt.flush Fmt.stderr ()
  end

let debug1 t a : unit = if !debug_on then Fmt.epr t a

let debug2 t a b : unit = if !debug_on then Fmt.epr t a b

let debug5 t a b c d e : unit = if !debug_on then Fmt.epr t a b c d e

let profile3 t a b c : unit = if !profiling_on then Fmt.epr t a b c

(* TODO: remove this *)
let err f = Fmt.failwith f

let debug_trace fmt =
  let open Format in
  if !debug_on then
    let fmt_wrapper = Format.asprintf fmt in
    let fmt_value = function
      | Value.I32 i -> sprintf "%ld" i  (* Convert `Value.I32` properly *)
      | v -> sprintf "Unsupported value: %s" (Value.to_string v)  (* Handle other cases safely *)
    in
    fprintf std_formatter ("%s\n") (fmt_wrapper fmt_value);