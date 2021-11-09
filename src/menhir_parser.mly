%token<String.t> ID
%token<String.t> NAME
%token<Unsigned.UInt32.t> U32
%token<Int64.t> INT
%token<Float.t> FLOAT
%token PARAM RESULT
%token FUNC_REF EXTERN_REF
%token I32 I64 F32 F64
%token CLZ CTZ POPCNT
%token ABS NEG SQRT CEIL FLOOR TRUNC NEAREST
%token SIGNED UNSIGNED
%token ADD SUB MUL DIV REM AND OR XOR SHL SHR ROTL ROTR MIN MAX COPYSIGN
%token EQZ
%token EQ NE LT GT LE GE
%token EXTEND8 EXTEND16 EXTEND32 EXTEND_I32 WRAPI64
%token TABLE GROW INIT COPY
%token TEE
%token ITEM
%token REF
%token SELECT
%token DEMOTE_F64
%token DROP
%token UNDERSCORE
%token GET
%token FILL
%token CONVERT
%token SAT
%token PROMOTE_F32
%token SIZE
%token SET
%token IS_NULL
%token LOCAL
%token NULL
%token REINTERPRET
%token GLOBAL
%token ELEM
%token STORE8 STORE16 STORE STORE32
%token BRTABLE
%token CALL
%token LOAD LOAD8
%token LOAD16
%token LOOP
%token DATA
%token BRIF BR
%token OFFSET
%token UNREACHABLE
%token CALL_INDIRECT
%token LOAD32
%token BLOCK ALIGN EQUAL MEMORY RETURN NOP
%token FUNC
%token EXPORT IMPORT
%token EXTERN
%token MUTABLE
%token MODULE
%token RPAR
%token LPAR
%token EOF
%token IF ELSE THEN
%token DOT
%token CONST
%token START TYPE
%token DECLARE
%token END
%token<string> NAT
%token<string> STRING

%{
open Types

type p_module_field =
  | MType of type_
  | MGlobal of global
  | MTable of table
  | MMem of mem
  | MFunc of func
  | MElem of elem
  | MData of data
  | MStart of start
  | MImport of import
  | MExport of export

(*
type p_param_or_result =
  | TmpParam of param
  | TmpResult of result_
*)

let u32 s =
  try Unsigned.UInt32.of_string s
  with Failure _ -> failwith "error u32 constant out of range"

(* TODO *)
let inline_type = Obj.magic
let bind_global = Obj.magic
let bind_func = Obj.magic
let if_ _ _ = Obj.magic
let block _ = Obj.magic
let call_indirect _ = Obj.magic
let loop _ = Obj.magic
let select = Obj.magic
let inline_type_explicit _ = Obj.magic

%}

%start <Types.module_> module_

%%

(* Helpers *)

let par(X) ==
  | LPAR; ~ = X; RPAR; <>

let string_list ==
  | l = list(STRING); { String.concat "" l }

(* Types *)

let ref_kind ==
  | FUNC; { Func_ref }
  | EXTERN; { Extern_ref }

let ref_type ==
  | FUNC_REF; { Func_ref }
  | EXTERN_REF; { Extern_ref }

let val_type :=
  | ~ = num_type; <Num_type>
  | ~ = ref_type; <Ref_type>

let global_type ==
  | t = val_type; { Const, t }
  | t = par(preceded(MUTABLE, val_type)); { Var, t }

let def_type ==
  | ~ = par(preceded(FUNC, func_type)); <>

let func_type :=
    | o = list(par(preceded(RESULT, list(val_type)))); { [], List.flatten o }
  | o = func_type_result; { [], o }
  | LPAR; PARAM; i = list(val_type); RPAR; x = func_type; {
    let i', o = x in
    ((i @ i', o) : func_type)
  }
  | LPAR; PARAM; _id = option(id); i = val_type; RPAR; x = func_type; {
    let i', o = x in
    ((i::i', o) : func_type)
  }

let func_type_result :=
  | LPAR; RESULT; l = list(val_type); RPAR; r = func_type_result; { l @ r }

let table_type ==
  | ~ = limits; ~ = ref_type; { limits, ref_type }

let mem_type ==
  | ~ = limits; <>

let limits ==
  | min = NAT; { {min = u32 min; max = None} }
  | min = NAT; max = NAT; { {min = u32 min; max = Some (u32 max) } }

let type_use ==
  | ~ = par(preceded(TYPE, indice)); <>

(* Immediates *)

let num ==
  | ~ = NAT; <>
  | ~ = INT; <>
  | ~ = FLOAT; <>

(* var *)
let indice ==
  | ~ = ID; <Symbolic>
  | ~ = U32; <Raw>

(* bind_var *)
let id ==
  | ~ = ID; <>


(* TODO: TO CLASSIFY *)

let labeling_opt == | { fun _ -> assert false }
let labeling_end_opt == | { assert false }

let num_type ==
  | I32; { Types.I32 }
  | I64; { Types.I64 }
  | F32; { Types.F32 }
  | F64; { Types.F64 }

let inn ==
  | I32; { Types.S32 }
  | I64; { Types.S64 }

let fnn ==
  | F32; { Types.S32 }
  | F64; { Types.S64 }

let sx ==
  | SIGNED; { S }
  | UNSIGNED; { U }

let iunop ==
  | CLZ; { Clz }
  | CTZ; { Ctz }
  | POPCNT; { Popcnt }

let ibinop ==
  | ADD; { (Add: Types.ibinop) }
  | SUB; { (Sub: Types.ibinop) }
  | MUL; { (Mul: Types.ibinop) }
  | DIV; s = sx; { (Div s: Types.ibinop) }
  | REM; s = sx; { Rem s }
  | AND; { And }
  | OR; { Or }
  | XOR; { Xor }
  | SHL; { Shl }
  | SHR; s = sx; { Shr s }
  | ROTL; { Rotl }
  | ROTR; { Rotr }

let itestop ==
  | EQZ; { Eqz }

let irelop ==
  | EQ; { (Eq : Types.irelop) }
  | NE; { (Ne : Types.irelop) }
  | LT; s = sx; { (Lt s: Types.irelop) }
  | GT; s = sx; { (Gt s: Types.irelop) }
  | LE; s = sx; { (Le s: Types.irelop) }
  | GE; s = sx; { (Ge s: Types.irelop) }

let funop ==
  | ABS; { Abs }
  | NEG; { Neg }
  | SQRT; { Sqrt }
  | CEIL; { Ceil }
  | FLOOR; { Floor }
  | TRUNC; { Trunc }
  | NEAREST; { Nearest }

let fbinop ==
  | ADD; { Add }
  | SUB; { Sub }
  | MUL; { Mul }
  | DIV; { Div }
  | MIN; { Min }
  | MAX; { Max }
  | COPYSIGN; { Copysign }

let frelop ==
  | EQ; { Eq }
  | NE; { Ne }
  | LT; { Lt }
  | GT; { Gt }
  | LE; { Le }
  | GE; { Ge }

let memarg ==
  | OFFSET; EQUAL; offset = U32; ALIGN; EQUAL; align = U32; {
    {offset = offset; align = align}
  }

let elem_idx == | ~ = indice; <>
let func_idx == | ~ = indice; <>
let table_idx == | ~ = indice; <>
let local_idx == | ~ = indice; <>
let data_idx == | ~ = indice; <>
let label_idx == | ~ = indice; <>
let global_idx == | ~ = indice; <>

let instr ==
| ~ = plain_instr; { [plain_instr] }
| ~ = select_instr_instr; { let e, es = select_instr_instr in e::es }
| ~ = call_instr_instr; { let e, es = call_instr_instr in e::es }
| ~ = block_instr; { [ block_instr ] }
| ~ = expr; { expr }

let plain_instr :=
  | NOP; { Nop }
  | UNREACHABLE; { Unreachable }
  | DROP; { Drop }
  | BR; ~ = label_idx; <Br>
  | BRIF; ~ = label_idx; <Br_if>
  | BRTABLE; { assert false }
  | RETURN; { Return }
  | CALL; ~ = func_idx; <Call>
  | LOCAL; DOT; GET; ~ = local_idx; <Local_get>
  | LOCAL; DOT; SET; ~ = local_idx; <Local_set>
  | LOCAL; DOT; TEE; ~ = local_idx; <Local_tee>
  | GLOBAL; DOT; GET; ~ = global_idx; <Global_get>
  | GLOBAL; DOT; SET; ~ = global_idx; <Global_set>
  | TABLE; DOT; GET; ~ = table_idx; <Table_get>
  | TABLE; DOT; SET; ~ = table_idx; <Table_set>
  | TABLE; DOT; SIZE; ~ = table_idx; <Table_size>
  | TABLE; DOT; GROW; ~ = table_idx; <Table_grow>
  | TABLE; DOT; FILL; ~ = table_idx; <Table_fill>
  | TABLE; DOT; COPY; src = table_idx; dst = table_idx; { Table_copy (src, dst) }
  | TABLE; DOT; INIT; ~ = table_idx; ~ = elem_idx; <Table_init>
(* TODO:
  | TABLE_GET {  table_get 0l) }  /* Sugar */
  | TABLE_SET { table_set 0l }  /* Sugar */
  | TABLE_SIZE { table_size 0l }  /* Sugar */
  | TABLE_GROW {table_grow 0l) }  /* Sugar */
  | TABLE_FILL {  table_fill 0l) }  /* Sugar */
  | TABLE_COPY  /* Sugar */
    { table_copy 0l  0l }
  | TABLE_INIT var  /* Sugar */
    { table_init 0l ($2 elem) }
 * *)
  (* TODO: check they're actually plain_instr and not instr: *)
  (* TODO: check that nothing is missing *)
  | ELEM; DOT; DROP; ~ = elem_idx; <Elem_drop>
  | I32; DOT; CONST; i = INT; { I32_const (Int64.to_int32 i) }
  | I64; DOT; CONST; ~ = INT; <I64_const>
  | F32; DOT; CONST; ~ = FLOAT; <F32_const>
  | ~ = inn; DOT; ~ = iunop; <I_unop>
  | ~ = fnn; DOT; ~ = funop; <F_unop>
  | ~ = inn; DOT; ~ = ibinop; <I_binop>
  | ~ = fnn; DOT; ~ = fbinop; <F_binop>
  | ~ = inn; DOT; ~ = itestop; <I_testop>
  | ~ = inn; DOT; ~ = irelop; <I_relop>
  | ~ = fnn; DOT; ~ = frelop; <F_relop>
  | ~ = inn; DOT; EXTEND8; SIGNED; <I_extend8_s>
  | ~ = inn; DOT; EXTEND16; SIGNED; <I_extend16_s>
  | I64; DOT; EXTEND32; SIGNED; { I64_extend32_s }
  | I32; DOT; WRAPI64; { I32_wrap_i64 }
  | I64; DOT; EXTEND_I32; ~ = sx; <I64_extend_i32>
  | ~ = inn; DOT; TRUNC; UNDERSCORE; ~ = fnn; s = sx; <I_trunc_f>
  | ~ = inn; DOT; TRUNC; UNDERSCORE; SAT; UNDERSCORE; ~ = fnn; s = sx; <I_trunc_sat_f>
  | F32; DOT; DEMOTE_F64; { F32_demote_f64 }
  | F64; DOT; PROMOTE_F32; { F64_promote_f32 }
  | ~ = fnn; DOT; CONVERT; UNDERSCORE; ~ = inn; s = sx; <F_convert_i>
  | ~ = inn; DOT; REINTERPRET; UNDERSCORE; ~ = fnn; <I_reinterpret_f>
  | ~ = fnn; DOT; REINTERPRET; UNDERSCORE; ~ = inn; <F_reinterpret_i>
  | REF; DOT; NULL; ~ = ref_type; <Ref_null>
  | REF; DOT; IS_NULL; { Ref_is_null }
  | REF; FUNC; ~ = func_idx; <Ref_func>
  | ~ = inn; DOT; LOAD; ~ = memarg; <I_load>
  | ~ = fnn; DOT; LOAD; ~ = memarg; <F_load>
  | ~ = inn; DOT; STORE; ~ = memarg; <I_store>
  | ~ = fnn; DOT; STORE; ~ = memarg; <F_store>
  | ~ = inn; DOT; LOAD8; ~ = sx; ~ = memarg; <I_load8>
  | ~ = inn; DOT; LOAD16; ~ = sx; ~ = memarg; <I_load16>
  | I64; DOT; LOAD32; ~ = sx; ~ = memarg; <I64_load32>
  | ~ = inn; DOT; STORE8; ~ = memarg; <I_store8>
  | ~ = inn; DOT; STORE16; ~ = memarg; <I_store16>
  | I64; DOT; STORE32; ~ = memarg; <I64_store32>
  | MEMORY; DOT; SIZE; { Memory_size }
  | MEMORY; DOT; GROW; { Memory_grow }
  | MEMORY; DOT; FILL; { Memory_fill }
  | MEMORY; DOT; COPY; { Memory_copy }
  | MEMORY; DOT; INIT; ~ = data_idx; <Memory_init>
  | DATA; DOT; DROP; ~ = data_idx; <Data_drop>

(* Instructions & Expressions *)

let select_instr ==
  | SELECT; ~ = select_instr_results; {
    let b, ts = select_instr_results in
    select (if b then (Some ts) else None)
  }

let select_instr_results :=
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = select_instr_results; {
    let _, ts = select_instr_results in
    true, l @ ts
  }
  | {false, []}

let select_instr_instr ==
  | SELECT; ~ = select_instr_results_instr; {
    let b, ts, es = select_instr_results_instr in
    select (if b then Some ts else None), es
  }

let select_instr_results_instr :=
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = select_instr_results_instr; {
    let _, ts, es = select_instr_results_instr in
    true, l @ ts, es
  }
  | ~ = instr; {
    false, [], instr
  }

let call_instr ==
  | CALL_INDIRECT; ~ = id; ~ = call_instr_type; {
    call_indirect id call_instr_type
  }
  | CALL_INDIRECT; ~ = call_instr_type; {
    call_indirect 0l call_instr_type
  }

let call_instr_type ==
  | ~ = type_use; ~ = call_instr_params; {
    match call_instr_params with
    | ([], []) -> type_use
    | ft -> inline_type_explicit type_use ft
  }
  | ~ = call_instr_params; {
    inline_type call_instr_params
  }

let call_instr_params :=
  | LPAR; PARAM; l = list(val_type); RPAR; ~ = call_instr_params; {
    let ts1, ts2 = call_instr_params in
    l @ ts1, ts2
  }
  | ~ = call_instr_results; {
    [], call_instr_results
  }

let call_instr_results :=
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = call_instr_results; {
    l @ call_instr_results
  }
  | { [] }

let call_instr_instr ==
  | CALL_INDIRECT; ~ = id; ~ = call_instr_type_instr; {
    let x, es = call_instr_type_instr in
    call_indirect id x, es
  }
  | CALL_INDIRECT; ~ = call_instr_type_instr; {
    let x, es = call_instr_type_instr in
    call_indirect 0l x, es
  }

let call_instr_type_instr ==
  | ~ = type_use; ~ = call_instr_params_instr; {
    let t = type_use (* TODO: type_ *) in
    match call_instr_params_instr with
    | ([], []), es -> t, es
    | ft, es -> inline_type_explicit t ft, es
  }
  | ~ = call_instr_params_instr; {
    let ft, es = call_instr_params_instr in
    inline_type ft, es
  }

let call_instr_params_instr :=
  | LPAR; PARAM; l = list(val_type); RPAR; ~ = call_instr_params_instr; {
    let (ts1, ts2), es = call_instr_params_instr in
    (l @ ts1, ts2), es
  }
  | ~ = call_instr_results_instr; {
    let ts, es = call_instr_results_instr in
    ([], ts), es
  }

let call_instr_results_instr :=
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = call_instr_results_instr; {
    let ts, es = call_instr_results_instr in
    l @ ts, es
  }
  | ~ = instr; {
    [], instr
  }

let block_instr ==
  | BLOCK; ~ = labeling_opt; b = block; END; ~ = labeling_end_opt; {
    let _c' = labeling_opt labeling_end_opt in
    let bt, es = b in
    block bt es
  }
  | LOOP; ~ = labeling_opt; ~ = block; END; ~ = labeling_end_opt; {
    let _c' = labeling_opt labeling_end_opt in
    let bt, es = block in
    loop bt es
  }
  | IF; ~ = labeling_opt; ~ = block; END; ~ = labeling_end_opt; {
    let _c' = labeling_opt labeling_end_opt in
    let bt, es = block in
    if_ bt es []
  }
  | IF; ~ = labeling_opt; ~ = block; ELSE; le1 = labeling_end_opt; ~ = instr_list; END; le2 = labeling_end_opt; {
    let _c' = labeling_opt (le1 @ le2) in
    let ts, es1 = block in
    if_ ts es1 instr_list
  }

let block ==
  | ~ = type_use; ~ = block_param_body; {
    Type_idx (inline_type_explicit type_use (fst block_param_body)), snd block_param_body
  }
  | ~ = block_param_body; {
    let bt = match fst block_param_body with
      | [], [] -> Val_type None
      | [], [t] -> Val_type (Some t)
      | ft -> Type_idx (inline_type ft)
    in
    bt, snd block_param_body
  }

let block_param_body :=
  | ~ = block_result_body; <>
  | LPAR; PARAM; l = list(val_type); RPAR; ~ = block_param_body; {
    let (ins, out), instr_list = block_param_body in
    (l @ ins, out), instr_list
  }

let block_result_body :=
  | ~ = instr_list; { ([], []), instr_list }
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = block_result_body; {
    let (ins, out), instr_list = block_result_body in
    (ins, l @out), instr_list
  }

let expr_aux ==
  | ~ = plain_instr; ~ = expr_list; { expr_list, plain_instr }
  | SELECT; ~ = select_expr_result; {
    let b, ts, es = select_expr_result in
    es, select (if b then Some ts else None)
  }
  | CALL_INDIRECT; _ = id; ~ = call_expr_type; {(* TODO: use id ? *)
    let x, es = call_expr_type in
    es, call_indirect call_expr_type x
  }
  | CALL_INDIRECT; ~ = call_expr_type; {
    let x, es = call_expr_type in
    es, call_indirect 0l x
  }
  | BLOCK; ~ = labeling_opt; b = block; {
    let _c' = labeling_opt in (* TODO ? *)
    let bt, es = b in
    [], block bt es
  }
  | LOOP; ~ = labeling_opt; b = block; {
    let _c' = labeling_opt in
    let bt, es = b in
    [], block bt es
  }
  | IF; ~ = labeling_opt; ~ = if_block; {
    let _c' = labeling_opt in
    let bt, (es, es1, es2) = if_block in
    es, if_ bt es1 es2
  }

let expr :=
  | expr_aux = par(expr_aux); {
    let es, e' = expr_aux in es @ [e']
  }

let select_expr_result :=
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = select_expr_result; {
    let _, ts, es = select_expr_result in
    true, l @ ts, es
  }
  | ~ = expr_list; { false, [], expr_list }

let call_expr_type ==
  | _ = type_use; ~ = call_expr_params; {
    match call_expr_params with
    (* TODO: | ([], []), es -> (Obj.magic type_use) type_, es *)
    (*| ft, es -> inline_type ((Obj.magic type_use) type_) ft, es*)
    | _ -> assert false
  }
  | ~ = call_expr_params; {
    let ft, es = call_expr_params in
    inline_type ft, es
  }

let call_expr_params :=
  | LPAR; PARAM; l = list(val_type); RPAR; ~ = call_expr_params; {
    let (ts1, ts2), es = call_expr_params in
    (l @ ts1, ts2), es
  }
  | ~ = call_expr_results; {
    let ts, es = call_expr_results in
    ([], ts), es
  }

let call_expr_results :=
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = call_expr_results; {
    let ts, es = call_expr_results in
    l @ ts, es
  }
  | ~ = expr_list; { [], expr_list }

let if_block ==
  | ~ = type_use; ~ = if_block_param_body; {
    Obj.magic (type_use, if_block_param_body)
  }
  | ~ = if_block_param_body; {
    Obj.magic (if_block_param_body)
  }

let if_block_param_body :=
  | ~ = if_block_result_body; <>
  | LPAR; PARAM; l = list(val_type); RPAR; ~ = if_block_param_body; {
    let (ins, out), if_ = if_block_param_body in
    (l @ ins, out), if_
  }

let if_block_result_body :=
  | ~ = if_; { ([], []), if_ }
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = if_block_result_body; {
    let (ins, out), if_ = if_block_result_body in
    (ins, l @ out), if_
  }

let if_ :=
  | ~ = expr; ~ = if_; {
    let es0, es1, es2 = if_ in
    expr @ es0, es1, es2
  }
  | LPAR; THEN; es1 = instr_list; RPAR; LPAR; ELSE; es2 = instr_list; RPAR; {
    [], es1, es2
  }
  | LPAR; THEN; ~ = instr_list; RPAR; {
    [], instr_list, []
  }

let instr_list :=
  | { [] }
  | ~ = select_instr; { [select_instr] }
  | ~ = call_instr; { [call_instr] }
  | ~ = instr; ~ = instr_list; { instr @ instr_list }

let expr_list :=
  | { [] }
  | ~ = expr; ~ = expr_list; { expr @ expr_list }

let const_expr ==
  | ~ = instr_list; <>

(* Functions *)

let func ==
  | FUNC; id = option(id); ~ = func_fields; {
    let x = bind_func id in
    func_fields x
  }

let func_fields :=
  | ~ = type_use; ~ = func_fields_body; {
    fun _x ->
      let _foo, f = func_fields_body in
      [{ f with type_f = type_use }],
      [], []
  }
  | ~ = func_fields_body; {
    fun _x ->
      let type_f, f = func_fields_body in
      let type_f = inline_type type_f in
      [{ f with type_f }],
      [], []
  }
  | ~ = inline_import; ~ = type_use; _ = func_fields_import; {
    fun _x ->
      let module_, name = inline_import in
      [],
      [{ module_; name; desc = Import_func (None, type_use) }],
      []
  }
  | ~ = inline_import; ~ = func_fields_import; {
    fun _x ->
      let module_, name = inline_import in
      let y = inline_type func_fields_import in (* TODO: ? *)
      [],
      [{ module_; name; desc = Import_func (None, y) }],
      []
  }
  | ~ = inline_export; ~ = func_fields; {
    fun x ->
      let fns, ims, exs = func_fields x in
      fns, ims, (inline_export (Export_func x))::exs
  }

let func_fields_import :=
  | ~ = func_fields_import_result; <>
  | LPAR; PARAM; ins = list(val_type); RPAR; ~ = func_fields_import; {
    let ins', out = func_fields_import in
    ins @ ins', out
  }
  | LPAR; PARAM; _ = id; ~ = val_type; RPAR; ~ = func_fields_import; {
    let ins', out = func_fields_import in
    val_type  :: ins', out
  }

let func_fields_import_result :=
  | { [], [] }
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = func_fields_import_result; {
    let ins, out = func_fields_import_result in
    ins, l @ out
  }

let func_fields_body :=
  | ~ = func_result_body; <>
  | LPAR; PARAM; l = list(val_type); RPAR; ~ = func_fields_body; {
    let ins, out = fst func_fields_body in
    let ins = l @ ins in
    (* TODO: anon_locals ? *)
    (ins, out), snd func_fields_body
  }
  | LPAR; PARAM; _ = id; ~ = val_type; RPAR; ~ = func_fields_body; {
    let ins, out = fst func_fields_body in
    let ins = val_type :: ins in
    (* TODO: use id ? *)
    (ins, out), snd func_fields_body
  }

let func_result_body :=
  | ~ = func_body; { ([], []), func_body }
  | LPAR; RESULT; l = list(val_type); RPAR; ~ = func_result_body; {
    let ins, out = fst func_result_body in
    let out = l @ out in
    (ins, out), snd func_result_body
  }

let func_body :=
  | body = expr; {
  let type_f = -1l in
  let type_f = Unsigned.UInt32.of_int32 type_f in
    let type_f = Raw type_f in
    { type_f; locals = []; body; id = None }
  }
  | LPAR; LOCAL; l = list(val_type); RPAR; ~ = func_body; {
    let l = List.map (fun v -> None, v) l in
    { func_body with locals = l @ func_body.locals  }
  }
  | LPAR; LOCAL; ~ = id; ~ = val_type; RPAR; ~ = func_body; {
    { func_body with locals = (Some id, val_type) :: func_body.locals }
  }

(* Tables, Memories & Globals *)

let table_use ==
  | TABLE; ~ = indice; <>

let memory_use ==
  | MEMORY; ~ = indice; <>

let offset ==
  | LPAR; OFFSET; ~ = const_expr; RPAR; <>
  | ~ = expr; <>

let elem_kind ==
  | FUNC; { Func_ref }

let elem_expr ==
  | LPAR; ITEM; ~ = const_expr; RPAR; <>
  | ~ = expr; <>

let elem_var ==
  | ~ = indice; <Ref_func>

let elem_list ==
  | ~ = elem_kind; ~ = list(elem_var); <>
  | ~ = ref_type; ~ = elem_expr; <>

(* TODO: store the ID ? *)
let elem ==
  | ELEM; _ = option(id); ~ = elem_list; {
    let type_, init = elem_list in
    let mode = Elem_passive in
    { type_; init = init; mode }
  }
  | ELEM; _ = option(id); ~ = table_use; ~ = offset; ~ = elem_list; {
    let type_, init = elem_list in
    let mode = Elem_active (table_use, offset) in
    { type_; init = init; mode }
  }
  | ELEM; _ = option(id); DECLARE; ~ = elem_list; {
    let type_, init = elem_list in
    let mode = Elem_declarative in
    { type_; init = init; mode }
  }
  | ELEM; _ = option(id); ~ = offset; ~ = elem_list; {
    let type_, init = elem_list in
    let mode = Elem_active (Raw Unsigned.UInt32.zero, offset) in
    { type_; init = init; mode }
  }
  | ELEM; _ = option(id); ~ = offset; init = list(elem_var); {
    let type_ = Func_ref in
    let mode = Elem_active (Raw Unsigned.UInt32.zero, offset) in
    { type_; init = init; mode }
  }

let table ==
| TABLE; id = option(id); ~ = table_fields; {
  match id with
  | None -> failwith "TODO (anon table)"
  | Some id -> table_fields (Symbolic id)
}

let init ==
  | ~ = list(elem_var); <>
  | ~ = elem_expr; <>

let table_fields :=
  | ~ = table_type; {
    fun _x ->
      [table_type], [], [], []
  }
  | ~ = inline_import; ~ = table_type; {
    fun _x ->
      let module_, name = inline_import in
      [], [],
      [{ module_; name; desc = Import_table (None, table_type) }],
      []
  }
  | ~ = inline_export; ~ = table_fields; {
    fun x ->
    let tabs, elems, ims, exs = table_fields x in
      tabs, elems, ims, (inline_export (Export_table x))::exs
  }
(* TODO: fix this conflict
  | ~ = ref_type; LPAR; ELEM; ~ = init; RPAR; {
    let min = Unsigned.UInt32.of_int @@ List.length init in
    let max = Some min in
    fun x ->
      let mode = Elem_active (x, [I32_const 0l]) in
      [{ min; max }, ref_type],
      [{ type_ = Func_ref; init; mode }],
      [], []
  }
     *)

(* TODO: use id *)
let data ==
  | DATA; _ = option(id); init = string_list; {
    { init; mode = Data_passive }
  }
  | DATA; _ = option(id); memory_use = option(memory_use); ~ = offset; init = string_list; {
    let memory_use = Option.value memory_use ~default:([I32_const.l]) in
    { init; mode = Data_active (memory_use, offset) }
  }

let memory ==
  | MEMORY; id = option(id); ~ = memory_fields; {
    match id with
    | None -> failwith "TODO (anon memory)"
    | Some id -> memory_fields (Symbolic id)
  }

let memory_fields :=
  | ~ = mem_type; {
    fun _x ->
      [None, mem_type], [], [], [] (* TODO: None ? *)
  }
  | ~ = inline_import; ~ = mem_type; {
    let module_, name = inline_import in
    fun _x ->
      [], [],
      [ { module_; name; desc = Import_mem (None, mem_type) } ], (* TODO: None ? *)
      []
  }
  | ~ = inline_export; ~ = memory_fields; {
    fun x ->
    let mems, data, ims, exs = memory_fields x in
    mems, data, ims, inline_export (Export_mem x) ::exs
  }
  | LPAR; DATA; init = string_list; RPAR; {
    fun x ->
    let min = Int32.(div (add (of_int (String.length init)) 65535l) 65536l) in
    let min = Unsigned.UInt32.of_int32 min in (* TODO: this shouldn't be needed.. *)
    let max = Some min in
    [ None, { min; max}  ],
    [ { init; mode = Data_active (x, [I32_const 0l]) } ],
    [], []
  }

let global ==
  | GLOBAL; id = option(id); ~ = global_fields; {
    let x = bind_global id in
    global_fields x
  }

(* TODO: None -> _x ? *)
let global_fields :=
  | type_ = global_type; init = const_expr; {
    fun _x ->
    [ { type_; init; id = None } ], [], []
  }
  | ~ = inline_import; ~ = global_type; {
    fun _x ->
    let module_, name = inline_import in
    [],
    [ { module_; name; desc = Import_global (None, global_type) } ],
    []
  }
  | ~ = inline_export; ~ = global_fields; {
      fun x ->
        let globs, ims, exs = global_fields x in
        globs, ims, (inline_export (Export_global x)) :: exs
  }

(* Imports & Exports *)

let import_desc ==
  | FUNC; ~ = option(id); ~ = type_use; <Import_func>
  | i = preceded(FUNC, pair(option(id), func_type)); {
    let id, ft = i in
    let ft = inline_type ft in
    Import_func (id, ft)
  }
  | TABLE; ~ = option(id); ~ = table_type; <Import_table>
  | MEMORY; ~ = option(id); ~ = mem_type; <Import_mem>
  | GLOBAL; ~ = option(id); ~ = global_type; <Import_global>

let import ==
  | IMPORT; module_ = NAME; name = NAME; desc = par(import_desc); {
    { module_; name; desc }
  }

let inline_import ==
  | LPAR; IMPORT; ~ = NAME; ~ = NAME; IMPORT; <>

let export_desc ==
  | FUNC; ~ = indice; <Export_func>
  | TABLE; ~ = indice; <Export_table>
  | MEMORY; ~ = indice; <Export_mem>
  | GLOBAL; ~ = indice; <Export_global>

let export ==
  | EXPORT; name = NAME; desc = par(export_desc); {
    { name; desc; }
  }

let inline_export ==
  | LPAR; EXPORT; name = NAME; RPAR;  {
    fun d -> { name; desc = d }
  }

(* Modules *)

let type_ ==
  | ~ = def_type; <>

let type_def ==
  | ~ = option(id); TYPE; ~ = type_; <>

let start ==
  | ~ = par(preceded(START, indice)); <>

let module_field :=
  | t = type_def; { [MType t] }
  | e = par(export); { [MExport e] }
  | f = par(func); {
    let funcs, ims, exs = f in
      (List.map (fun f -> MFunc f) funcs)
    @ (List.map (fun i -> MImport i) ims)
    @ (List.map (fun e -> MExport e) exs)
  }
  | s = par(start); { [MStart s] }
  | i = par(import); { [MImport i] }
  | e = par(elem); { [MElem e] }
  | g = par(global); {
    let globs, ims, exs = g in
      (List.map (fun g -> MGlobal g) globs)
    @ (List.map (fun i -> MImport i) ims)
    @ (List.map (fun e -> MExport e) exs)
  }
  | t = par(table); {
    let tabs, elems, ims, exs = t in
      (List.map (fun t -> MTable (None, t)) tabs) (* TODO: is it really None ? *)
    @ (List.map (fun e -> MElem e) elems)
    @ (List.map (fun i -> MImport i) ims)
    @ (List.map (fun e -> MExport e) exs)
  }
  | m = par(memory); {
    let mems, data, ims, exs = m in
      (List.map (fun (id, m) -> MMem (id, m)) mems)
    @ (List.map (fun d -> MData d) data)
    @ (List.map (fun i -> MImport i) ims)
    @ (List.map (fun e -> MExport e) exs)
  }

let module_ :=
  | LPAR; MODULE; id = option(id); fields = list(par(module_field)); RPAR; EOF; {
    let fields = List.flatten fields in
    let res = List.fold_left (fun m f ->
      match f with
      | MExport e -> { m with exports = e::m.exports }
      | MFunc f -> { m with funcs = f::m.funcs }
      | MStart start ->
        if Option.is_some m.start then failwith "multiple start sections"
        else { m with start = Some start }
      | MImport i ->
        if m.funcs <> [] then failwith "import after function definition"
        else if m.mems <> [] then failwith "import after memory definition"
        else if m.tables <> [] then failwith "import after table definition"
        else if m.globals <> [] then failwith "import after global definition"
        else { m with imports = i::m.imports }
      | MData d -> { m with datas = d::m.datas }
      | MElem e -> { m with elems = e::m.elems }
      | MMem mem -> { m with mems = mem::m.mems }
      | MType t -> { m with types = t::m.types }
      | MGlobal g -> { m with globals = g::m.globals }
      | MTable t -> { m with tables = t::m.tables }
      ) {
        id = id;
        types = [];
        funcs = [];
        tables = [];
        mems = [];
        globals = [];
        elems = [];
        datas = [];
        start = None;
        imports = [];
        exports = [];
      }
      fields
    in
    { res with
      types = List.rev res.types;
      funcs = List.rev res.funcs;
      tables = List.rev res.tables;
      mems = List.rev res.mems;
      globals = List.rev res.globals;
      elems = List.rev res.elems;
      datas = List.rev res.datas;
      imports = List.rev res.imports;
      exports = List.rev res.exports;
    }
  }
