(* Copyright 2003 Yamagata Yoriyuki. distributed with LGPL *)
(* Modified by Edgar Friendly <thelema314@gmail.com> *)

include BatAvlTree

type t = (int * int) tree
type elt = int

let rec mem (n:int) s =
  if is_empty s then false else
    let v1, v2 = root s in
    if n < v1 then mem n (left_branch s) else
    if v1 <= n && n <= v2 then true else
      mem n (right_branch s)

(*$T mem
  let t = empty |> add_range 1 10 |> add_range 10 20 in \
  mem 1 t && mem 5 t && mem 20 t && not (mem 21 t) && not (mem 0 t)

  let t = Enum.append (1--9) (20 --- 15) |> Enum.map (fun i -> i,i) |> of_enum in \
  mem 1 t && mem 5 t && mem 15 t && not (mem 10 t) && not (mem 14 t)

*)

let rec add n s =
  if is_empty s then make_tree empty (n, n) empty else
    let (v1, v2) as v = root s in
    let s0 = left_branch s in
    let s1 = right_branch s in
    if v1 <> min_int && n < v1 - 1 then make_tree (add n s0) v s1 else
    if v2 <> max_int && n > v2 + 1 then make_tree s0 v (add n s1) else
    if n + 1 = v1 then
      if not (is_empty s0) then
        let (u1, u2), s0' = split_rightmost s0 in
        if u2 <> max_int && u2 + 1 = n then
          make_tree s0' (u1, v2) s1
        else
          make_tree s0 (n, v2) s1
      else
        make_tree s0 (n, v2) s1
    else if v2 + 1 = n then
      if not (is_empty s1) then
        let (u1, u2), s1' = split_leftmost s1 in
        if n <> max_int && n + 1 = u1 then
          make_tree s0 (v1, u2) s1'
        else
          make_tree s0 (v1, n) s1
      else
        make_tree s0 (v1, n) s1
    else s

(*$Q add
  (Q.list Q.small_int) (fun l -> let t = List.fold_left (fun s x -> add x s) empty l in List.for_all (fun i -> mem i t) l)
*)

let rec from n s =
  if is_empty s then empty else
    let (v1, v2) as v = root s in
    let s0 = left_branch s in
    let s1 = right_branch s in
    if n < v1 then make_tree (from n s0) v s1 else
    if n > v2 then from n s1 else
      make_tree empty (n, v2) s1

let after n s = if n = max_int then empty else from (n + 1) s

let rec until n s =
  if is_empty s then empty else
    let (v1, v2) as v = root s in
    let s0 = left_branch s in
    let s1 = right_branch s in
    if n > v2 then make_tree s0 v (until n s1) else
    if n < v1 then until n s0 else
      make_tree s0 (v1, n) empty

let before n s = if n = min_int then empty else until (n - 1) s

(*$= from & ~cmp:equal ~printer:(IO.to_string print)
  (from 3 (of_list [1,5])) (of_list [3,5])
  empty (from 3 (of_list [1,2]))
*)

(*$= until & ~cmp:equal ~printer:(IO.to_string print)
  (until 3 (of_list [1,5])) (of_list [1,3])
  empty (until 3 (of_list [4,5]))
*)

let add_range n1 n2 s =
  if n1 > n2 then invalid_arg (Printf.sprintf "ISet.add_range - %d > %d" n1 n2) else
    let n1, l =
      if n1 = min_int then n1, empty else
        let l = until (n1 - 1) s in
        if is_empty l then n1, empty else
          let (v1, v2), l' = split_rightmost l in
          if v2 + 1 = n1 then v1, l' else n1, l in
    let n2, r =
      if n2 = max_int then n2, empty else
        let r = from (n2 + 1) s in
        if is_empty r then n2, empty else
          let (v1, v2), r' = split_leftmost r in
          if n2 + 1 = v1 then v2, r' else n2, r in
    make_tree l (n1, n2) r

let singleton n = singleton_tree (n, n)

(*$T singleton
  singleton 3 |> mem 3
  singleton 3 |> mem 4 |> not
*)

let rec remove n s =
  if is_empty s then empty else
    let (v1, v2) as v = root s in
    let s1 = left_branch s in
    let s2 = right_branch s in
    if n < v1 then make_tree (remove n s1) v s2
    else if n = v1 then
      if v1 = v2 then concat s1 s2 else
        make_tree s1 (v1 + 1, v2) s2
    else if n > v1 && n < v2 then
      let s = make_tree s1 (v1, n - 1) empty in
      make_tree s (n + 1, v2) s2
    else if n = v2 then make_tree s1 (v1, v2 - 1) s2 else
      make_tree s1 v (remove n s2)

(*$= remove & ~cmp:equal ~printer:(IO.to_string print)
  empty (remove 3 (singleton 3))
  (of_list [1,5] |> remove 5) (of_list [1,4])
  (of_list [1,5] |> remove 1) (of_list [2,5])
  (of_list [1,5] |> remove 3) (of_list [1,2;4,5])
  (of_list [4,6;1,3;8,10] |> remove 1) (of_list [2,3;4,6;8,10])
  (of_list [4,6;1,3;8,10] |> remove 10) (of_list [1,3;4,6;8,9])
*)

let remove_range n1 n2 s =
  if n1 > n2 then invalid_arg "ISet.remove_range" else
    concat (before n1 s) (after n2 s)

(*$= remove_range & ~cmp:equal ~printer:(IO.to_string print)
  empty (remove_range 10 15 (of_list [10,15]))
  (of_list [0,20] |> remove_range 3 5) (of_list [0,2;6,20])
  (of_list [0,20] |> remove_range 3 5 |> remove_range 8 10 |> remove_range 5 8) (of_list [0,2;11,20])
*)

let rec union s1 s2 =
  if is_empty s1 then s2 else
  if is_empty s2 then s1 else
    let s1, s2 = if height s1 > height s2 then s1, s2 else s2, s1 in
    let n1, n2 = root s1 in
    let l1 = left_branch s1 in
    let r1 = right_branch s1 in
    let l2 = before n1 s2 in
    let r2 = after n2 s2 in
    let n1, l =
      if n1 = min_int then n1, empty else
        let l = union l1 l2 in
        if is_empty l then n1, l else
          let (v1, v2), l' = split_rightmost l in (* merge left *)
          if v2 + 1 = n1 then v1, l' else n1, l in
    let n2, r =
      if n1 = max_int then n2, empty else
        let r = union r1 r2 in
        if is_empty r then n2, r else
          let (v1, v2), r' = split_leftmost r in (* merge right *)
          if n2 + 1 = v1 then v2, r' else n2, r in
    make_tree l (n1, n2) r

(*$= union & ~cmp:equal ~printer:(IO.to_string print)
  (union (of_list [3,5]) (of_list [1,3])) (of_list [1,5])
  (union (of_list [3,5]) (of_list [1,2])) (of_list [1,5])
  (union (of_list [3,5]) (of_list [1,5])) (of_list [1,5])
  (union (of_list [1,5]) (of_list [3,5])) (of_list [1,5])
  (union (of_list [1,2]) (of_list [4,5])) (of_list [1,2;4,5])
*)

let rec inter s1 s2 =
  if is_empty s1 then empty else
  if is_empty s2 then empty else
    let s1, s2 = if height s1 > height s2 then s1, s2 else s2, s1 in
    let n1, n2 = root s1 in
    let l1 = left_branch s1 in
    let r1 = right_branch s1 in
    let l2 = before n1 s2 in
    let r2 = after n2 s2 in
    let m = until n2 (from n1 s2) in
    concat (concat (inter l1 l2) m) (inter r1 r2)

(*$= inter & ~cmp:equal ~printer:(IO.to_string print)
  (inter (of_list [1,5]) (of_list [2,3])) (of_list [2,3])
  (inter (of_list [1,4]) (of_list [2,6])) (of_list [2,4])
*)

let rec compl_aux n1 n2 s =
  if is_empty s then add_range n1 n2 empty else
    let v1, v2 = root s in
    let l = left_branch s in
    let r = right_branch s in
    let l = if v1 = min_int then empty else compl_aux n1 (v1 - 1) l in
    let r = if v2 = max_int then empty else compl_aux (v2 + 1) n2 r in
    concat l r

let compl s = compl_aux min_int max_int s

let diff s1 s2 = inter s1 (compl s2)

(*$= diff & ~cmp:equal ~printer:(IO.to_string print)
  (diff (of_list [1,5]) (of_list [2,3])) (of_list [1,1;4,5])
  (diff (of_list [1,3;6,8]) (of_list [3,6])) (of_list [1,2;7,8])
*)

let rec compare_aux x1 x2 =
  match x1, x2 with
    [], [] -> 0
  | `Set s :: rest, x ->
    if is_empty s then compare_aux rest x2 else
      let l = left_branch s in
      let v = root s in
      let r = right_branch s in
      compare_aux (`Set l :: `Range v :: `Set r :: rest) x
  | _x, `Set s :: rest ->
    if is_empty s then compare_aux x1 rest else
      let l = left_branch s in
      let v = root s in
      let r = right_branch s in
      compare_aux x1 (`Set l :: `Range v :: `Set r :: rest)
  | `Range ((v1, v2)) :: rest1, `Range ((v3, v4)) :: rest2 ->
    let sgn = BatInt.compare v1 v3 in
    if sgn <> 0 then sgn else
      let sgn = BatInt.compare v2 v4 in
      if sgn <> 0 then sgn else
        compare_aux rest1 rest2
  | [], _ -> ~-1
  | _, [] -> 1

let compare s1 s2 = compare_aux [`Set s1] [`Set s2]

let equal s1 s2 = compare s1 s2 = 0

(*$T equal
  not (equal (of_list [3,3;5,5]) (of_list [3,3;1,1]))
*)

let ord = BatOrd.ord compare

let rec subset s1 s2 =
  if is_empty s1 then true else
  if is_empty s2 then false else
    let v1, v2 = root s2 in
    let l2 = left_branch s2 in
    let r2 = right_branch s2 in
    let l1 = before v1 s1 in
    let r1 = after v2 s1 in
    (subset l1 l2) && (subset r1 r2)

(*$T subset
  subset (of_list [1,3]) (of_list [1,5])
  subset (of_list [1,3]) (of_list [1,3])
  subset (of_list []) (of_list [1,5])
  not (subset (of_list [0,3]) (of_list [1,5]))
  not (subset (of_list [0,6]) (of_list [1,5]))
*)

let fold_range f s x0 = BatAvlTree.fold (fun (n1, n2) x -> f n1 n2 x) s x0

let fold f s x0 =
  let rec g n1 n2 a =
    if n1 = n2 then f n1 a else
      g (n1 + 1) n2 (f n1 a) in
  fold_range g s x0

(*$= fold & ~cmp:Int.equal ~printer:string_of_int
  (fold (+) (of_list [1,3]) 0) 6
*)

let iter proc s = fold (fun n () -> proc n) s ()

(*$T iter
  let a = ref 0 in iter (fun _ -> incr a) (of_list [1,3;5,8]); !a = 7
*)

let iter_range proc = BatAvlTree.iter (fun (n1, n2) -> proc n1 n2)

(*$T iter_range
  let a = ref 0 in iter_range (fun _ _ -> incr a) (of_list [1,3;5,8]); !a = 2
*)

let for_all p s =
  let rec test_range n1 n2 =
    if n1 = n2 then p n1 else
      p n1 && test_range (n1 + 1) n2 in
  let rec test_set s =
    if is_empty s then true else
      let n1, n2 = root s in
      test_range n1 n2 &&
      test_set (left_branch s) &&
      test_set (right_branch s) in
  test_set s

(*$T for_all
  for_all (fun x -> x < 10) (of_list [1,3;2,7])
  not (for_all (fun x -> x = 5) (of_list [4,5]))
*)

let exists p s =
  let rec test_range n1 n2 =
    if n1 = n2 then p n1 else
      p n1 || test_range (n1 + 1) n2 in
  let rec test_set s =
    if is_empty s then false else
      let n1, n2 = root s in
      test_range n1 n2 ||
      test_set (left_branch s) ||
      test_set (right_branch s) in
  test_set s

(*$T exists
  exists (fun x -> x = 5) (of_list [1,10])
  not (exists (fun x -> x = 5) (of_list [1,3;7,10]))
*)

let filter_range p n1 n2 a =
  let rec loop n1 n2 a = function
      None ->
      if n1 = n2 then
        make_tree a (n1, n1) empty
      else
        loop (n1 + 1) n2 a (if p n1 then Some n1 else None)
    | Some v1 as x ->
      if n1 = n2 then	make_tree a (v1, n1) empty else
      if p n1 then
        loop (n1 + 1) n2 a x
      else
        loop (n1 + 1) n2 (make_tree a (v1, n1 - 1) empty) None in
  loop n1 n2 a None

let filter p s = fold_range (filter_range p) empty s

(*$T filter
  true || equal (filter (fun x -> x <> 5) (of_list [1,10])) (of_list [1,4;6,10])
*)

let partition_range p n1 n2 (a, b) =
  let rec loop n1 n2 acc =
    let acc =
      let a, b, (v, n) = acc in
      if p n1 = v then acc else
      if v then
        (make_tree a (n, n1) empty, b, (not v, n1))
      else
        (a, make_tree b (n, n1) empty, (not v, n1)) in
    if n1 = n2 then
      let a, b, (v, n) = acc in
      if v then	(make_tree a (n, n1) empty, b) else
        (a, make_tree b (n, n1) empty)
    else
      loop (n1 + 1) n2 acc in
  loop n1 n2 (a, b, (p n1, n1))

let partition p s = fold_range (partition_range p) s (empty, empty)

let cardinal s =
  fold_range (fun n1 n2 c -> c + n2 - n1 + 1) s 0

(*$T cardinal
  cardinal (of_list [1,3;5,9]) = 8
*)

let rev_ranges s =
  fold_range (fun n1 n2 a -> (n1, n2) :: a) s []

let rec burst_range n1 n2 a =
  if n1 = n2 then n1 :: a else
    burst_range n1 (n2 - 1) (n2 :: a)

let elements s =
  let f a (n1, n2) = burst_range n1 n2 a in
  List.fold_left f [] (rev_ranges s)

(*$Q ranges;of_list
  (Q.list (Q.pair Q.int Q.int)) (fun l -> \
    let norml = List.map (fun (x,y) -> if x < y then (x,y) else (y,x)) l in \
    let set = of_list norml in \
    equal set (ranges set |> of_list) \
  )
*)

let ranges s = List.rev (rev_ranges s)

let min_elt s =
  let (n, _), _ = split_leftmost s in
  n

let max_elt s =
  let (_, n), _ = split_rightmost s in
  n

(*$= min_elt & ~printer:string_of_int
  3 (of_list [4,7;8,22;23,23;3,3] |> min_elt)
  1 (of_list [4,7;8,12;23,23;1,3] |> min_elt)
*)

(*$T min_elt
  Result.(catch min_elt empty |> is_exn Not_found)
*)

(*$= max_elt & ~printer:string_of_int
  23 (of_list [4,7;8,22;23,23;3,3] |> max_elt)
  21 (of_list [4,7;8,12;15,21;1,3] |> max_elt)
*)

(*$T max_elt
  Result.(catch max_elt empty |> is_exn Not_found)
*)

let choose s = fst (root s)

let of_list l = List.fold_left (fun s (lo,hi) -> add_range lo hi s) empty l
let of_enum e = BatEnum.fold (fun s (lo,hi) -> add_range lo hi s) empty e

let print oc t =
  let print_range oc (lo,hi) =
    if lo=hi then BatInt.print oc lo
    else BatTuple.Tuple2.printn BatInt.print oc (lo,hi)
  in
  BatEnum.print print_range oc (enum t)

  (*$= print & ~printer:(fun x -> x)
    "(1,3) (5,6)" (IO.to_string print (of_list [1,3;5,6]))
  *)
