(**************************************************************************)
(*  This is part of ATBR, it is distributed under the terms of the        *)
(*         GNU Lesser General Public License version 3                    *)
(*              (see file LICENSE for more details)                       *)
(*                                                                        *)
(*       Copyright 2009-2010: Thomas Braibant, Damien Pous.               *)
(**************************************************************************)

(** Syntactic model of regular expressions 

    Terms of arbitrary Kleene algebras will be reified into this one,
    which is syntactic, and allows us to define automata
    constructions.  

    We also prove the untyping theorem for Kleene algebras in this module, 
    to obtain the above reification.

    We define the [kleene_clean_zeros] tactic, to remove zeros from KA expressions.
*)

Require Import Common.
Require Import Classes.
Require Import Graph.
Require Import SemiLattice.
Require Import SemiRing.
Require Import KleeneAlgebra.
Require Import MxGraph.
Require        Reification.

Set Implicit Arguments.
Unset Strict Implicit.

Module RegExp.

  Inductive regex :=
  | one: regex
  | zero: regex
  | dot: regex -> regex -> regex
  | plus: regex -> regex -> regex
  | star: regex -> regex
  | var: positive -> regex
    .

  (** free equality, generated by KA axioms  *)
  Inductive equal: regex -> regex -> Prop :=
  | refl_one: equal one one
  | refl_zero: equal zero zero
  | refl_var: forall i, equal (var i) (var i)

  | dot_assoc: forall x y z, equal (dot x (dot y z)) (dot (dot x y) z)
  | dot_neutral_left: forall x, equal (dot one x) x
  | dot_neutral_right: forall x, equal (dot x one) x

  | plus_neutral_left: forall x, equal (plus zero x) x
  | plus_idem: forall x, equal (plus x x) x
  | plus_assoc: forall x y z, equal (plus x (plus y z)) (plus (plus x y) z)
  | plus_com: forall x y, equal (plus x y) (plus y x)

  | dot_ann_left: forall x, equal (dot zero x) zero
  | dot_ann_right: forall x, equal (dot x zero) zero
  | dot_distr_left: forall x y z, equal (dot (plus x y) z) (plus (dot x z) (dot y z))
  | dot_distr_right: forall x y z, equal (dot x (plus y z)) (plus (dot x y) (dot x z))

  | star_make_left: forall a, equal (plus one (dot (star a) a)) (star a)
  | star_make_right: forall a, equal (plus one (dot a (star a))) (star a)
  | star_destruct_left: forall a x, equal (plus (dot a x) x) x -> equal (plus (dot (star a) x) x) x
  | star_destruct_right: forall a x, equal (plus (dot x a) x) x -> equal (plus (dot x (star a)) x) x

  | dot_compat: forall x x', equal x x' -> forall y y', equal y y' -> equal (dot x y) (dot x' y')
  | plus_compat: forall x x', equal x x' -> forall y y', equal y y' -> equal (plus x y) (plus x' y')
  | star_compat: forall x x', equal x x' -> equal (star x) (star x')
  | equal_trans: forall x y z, equal x y -> equal y z -> equal x z
  | equal_sym: forall x y, equal x y -> equal y x  
    .

  Lemma equal_refl: forall x, equal x x.
  Proof. induction x; constructor; assumption. Qed.


  Definition is_zero t := match t with zero => true | _ => false end.
  Definition is_one t := match t with one => true | _ => false end.

  Lemma Is_zero: forall t, is_zero t = true -> t = zero.
  Proof. intros t H. destruct t; auto; discriminate. Qed.

  Lemma Is_one: forall t, is_one t = true -> t = one.
  Proof. intros t H. destruct t; auto; discriminate. Qed.

  Ltac leaf x :=  
    match x with 
      | context [is_one ?u] => fail 1
      | context [is_zero ?u] => fail 1
      | _ => idtac
    end.

  Ltac destruct_tests := 
    repeat (
      repeat match goal with
               | H: is_zero ?x = _ |- _ => rewrite (Is_zero H) in * || rewrite H in *
               | H: is_one  ?x = _ |- _ => rewrite (Is_one H) in * || rewrite H in *
               | H: ?x = ?x |- _ => clear H
               | H: ?x <> ?y |- _ => solve [elimtype False; apply H; trivial]
             end;
      repeat match goal with 
               | |- context[is_zero ?x] => leaf x; let Z := fresh "Z" in case_eq (is_zero x); intro Z
               | |- context[is_one ?x] => leaf x; let O := fresh "O" in case_eq (is_one x); intro O
             end;
      try discriminate).

  
  Section Def.
  
    Program Instance RE_Graph: Graph := {
      T := unit;
      X A B := regex;
      equal A B := RegExp.equal
    }.
    Next Obligation.
      constructor. 
      exact RegExp.equal_refl.
      exact RegExp.equal_sym.
      exact RegExp.equal_trans.
    Qed.
  
    Instance RE_SemiLattice_Ops: SemiLattice_Ops := {
      plus A B := RegExp.plus;
      zero A B := RegExp.zero
    }.
  
    Instance RE_Monoid_Ops: Monoid_Ops := {
      dot A B C := RegExp.dot;
      one A := RegExp.one
    }.
    
    Instance RE_Star_Op: Star_Op := { 
      star A := RegExp.star
    }.
    
    Instance RE_SemiLattice: SemiLattice.
    Proof.
      constructor; repeat intro; simpl in *;
      constructor; assumption.
    Qed.
  
    Instance RE_Monoid: Monoid.
    Proof.
      constructor; repeat intro; simpl in *;
        constructor; assumption.
    Qed.
  
    Instance RE_SemiRing: IdemSemiRing.
    Proof.
      apply (Build_IdemSemiRing RE_Monoid RE_SemiLattice);
      repeat intro; simpl in *;
        constructor; assumption.
    Qed.
  
    Instance RE_KleeneAlgebra: KleeneAlgebra.
    Proof.
      constructor; 
      try exact RE_SemiRing;
      repeat intro; simpl in *;
        constructor; assumption.
    Qed.
  
  End Def.
  
  Module Load.
  
    Existing Instance RE_Graph.
    Existing Instance RE_SemiLattice_Ops.
    Existing Instance RE_Monoid_Ops.
    Existing Instance RE_SemiLattice.
    Existing Instance RE_Star_Op.
    Existing Instance RE_SemiRing.
    Existing Instance RE_Monoid.
    Existing Instance RE_KleeneAlgebra.
    
    Canonical Structure RE_Graph.
    
    Import Classes.

    Notation tt := (tt: @T RE_Graph).
    Notation regex := (@X RE_Graph tt tt).
    Notation KMX n m := (@X (@mx_Graph RE_Graph) (n,tt)%nat (m,tt)%nat).
    Notation var i := (var i: regex).  

    Transparent equal plus dot one zero star. 
    Global Opaque T.
  
    Ltac fold_regex :=
      change RegExp.equal with (@equal RE_Graph tt tt) ; 
      change RegExp.one with (@one RE_Graph RE_Monoid_Ops tt) ;
        change RegExp.dot with (@dot RE_Graph RE_Monoid_Ops tt tt tt) ;
          change RegExp.zero with (@zero RE_Graph RE_SemiLattice_Ops tt tt) ;
            change RegExp.plus with (@plus RE_Graph RE_SemiLattice_Ops tt tt) ;
              change RegExp.star with (@star RE_Graph RE_Star_Op tt).
      
  End Load.


  (** Cleaning regular expressions so that they no longer contain
      zeros (but the last if the expression reduces to zero ...)  *)
  Module Clean.

    Import Load.
    Section S.
    
      Let cleaning_dot x y := 
        if is_zero x then zero
          else if is_zero y then zero
            else dot x y.
      Let cleaning_plus x y := 
        if is_zero x then y
          else if is_zero y then x
            else plus x y.
      Let cleaning_star x := 
        if is_zero x then one else star x.
    
    
      (** [clean x] removes all zeros from [x] (but the last one, if the expression reduces to zero...) *)
      Fixpoint rewrite (x: regex): regex := 
        match x with
          | dot x y => cleaning_dot (rewrite x) (rewrite y)
          | plus x y => cleaning_plus (rewrite x) (rewrite y)
          | star x => cleaning_star (rewrite x)
          | x => x
        end.
    
      Lemma clean_dot: forall (e f: regex), (cleaning_dot e f: regex) == e * f.
      Proof. 
        intros. unfold cleaning_dot. destruct_tests; fold_regex; auto with algebra.
      Qed.
      
      Lemma clean_plus: forall (e f: regex), (cleaning_plus e f: regex) == e + f.
      Proof. 
        intros. unfold cleaning_plus. destruct_tests; fold_regex; auto with algebra.
      Qed.
      
      Lemma clean_star: forall (e f: regex), (cleaning_star e: regex) == e #.
      Proof. 
        intros. unfold cleaning_star. destruct_tests; fold_regex; auto with algebra. 
      Qed.
      
      (** the rewriting procedure is correct *)
      Theorem correct: forall e, e == rewrite e.
      Proof.
        induction e; simpl; trivial; fold_regex. 
        rewrite clean_dot; auto with compat. 
        rewrite clean_plus; auto with compat. 
        rewrite clean_star; auto with compat. 
      Qed.
        
    End S.
    
    
    (** [rewrite] is idempotent *)
    Lemma rewrite_idem: forall x, rewrite (rewrite x) = rewrite x.
    Proof.
      intro x; induction x; trivial; simpl; destruct_tests; trivial; simpl.
      rewrite IHx1, IHx2. destruct_tests. trivial.
      rewrite IHx1, IHx2. destruct_tests. trivial.
      rewrite IHx. destruct_tests. trivial.
    Qed.
    
    (** two equal terms equally rewrite two zero *)
    Lemma equal_rewrite_zero_equiv : forall x y, equal x y -> is_zero (rewrite x) = is_zero (rewrite y).
    Proof.
      intros; induction H; simpl; destruct_tests; trivial.  
    Qed.
    
  End Clean.


  (** Untyping theorem for Kleene algebra, typed reification  *)
  Module Untype.

    Section protect.

    Notation clean := Clean.rewrite.  

    (** first we show that equality proofs can be factorised, so as to use the annihilation laws at first  *)

    (** strong equality, without annihilation *)
    (* The order of constructors is important for the later proofs *)
    Inductive sequal: regex -> regex -> Prop :=
    | sequal_refl_one: sequal one one
    | sequal_refl_zero: sequal zero zero
    | sequal_refl_var: forall i, sequal (var i) (var i)
      
    | sequal_dot_assoc: forall x y z, sequal (dot x (dot y z)) (dot (dot x y) z)
    | sequal_dot_neutral_left: forall x, sequal (dot one x) x
    | sequal_dot_neutral_right: forall x, sequal (dot x one) x
    | sequal_dot_distr_left: forall x y z, is_zero (clean z) = false -> sequal (dot (plus x y) z) (plus (dot x z) (dot y z))
    | sequal_dot_distr_right:  forall x y z,  is_zero (clean x) = false -> sequal (dot x (plus y z)) (plus (dot x y) (dot x z))
    
    | sequal_plus_assoc: forall x y z, sequal (plus x (plus y z)) (plus (plus x y) z)
    | sequal_plus_idem: forall x, sequal (plus x x) x
    | sequal_plus_com: forall x y, sequal (plus x y) (plus y x)
    
    | sequal_star_make_left: forall a, sequal (plus one (dot (star a) a)) (star a)
    | sequal_star_make_right: forall a, sequal (plus one (dot a (star a))) (star a)
    | sequal_star_destruct_left: forall a x, is_zero (clean x) = false -> sequal (plus (dot a x) x) x -> sequal (plus (dot (star a) x) x) x
    | sequal_star_destruct_right: forall a x, is_zero (clean x) = false -> sequal (plus (dot x a) x) x -> sequal (plus (dot x (star a)) x) x
    
    | sequal_dot_compat: forall x x', sequal x x' -> forall y y', sequal y y' -> sequal (dot x y) (dot x' y')
    | sequal_plus_compat: forall x x', sequal x x' -> forall y y', sequal y y' -> sequal (plus x y) (plus x' y')
    | sequal_star_compat: forall x x', sequal x x' -> sequal (star x) (star x')
    | sequal_trans: forall x y z, sequal x y -> sequal y z -> sequal x z
    | sequal_sym: forall x y, sequal x y -> sequal y x
        .
    
    Lemma sequal_equal x y: sequal x y -> equal x y .
    Proof.
      intros; induction H; try solve [constructor; auto ].
      eapply equal_trans; eauto.
    Qed.
    
    Lemma sequal_refl: forall x, sequal x x.
    Proof. 
      induction x; constructor; assumption.
    Qed.
    Local Hint Resolve sequal_refl.
    Local Hint Constructors sequal.
    
    Lemma sequal_clean_zero_equiv x : sequal (clean x) zero -> is_zero (clean x) = true.
    Proof.
      intros; rewrite <- (Clean.rewrite_idem x). apply sequal_equal in H.
      rewrite (Clean.equal_rewrite_zero_equiv H). reflexivity.
    Qed.
    
    (** factorisation theorem  *)
    Theorem equal_to_sequal : forall x y, equal x y -> sequal (clean x) (clean y).
    Proof.
      intros; induction H; simpl in *; trivial; destruct_tests; simpl; trivial;
        try solve 
          [ constructor; rewrite ? Clean.rewrite_idem; trivial
          | match goal with H: sequal (clean _) zero |- _ => 
              rewrite (sequal_clean_zero_equiv H) in *; discriminate end
          | match goal with H: sequal zero (clean _) |- _ => 
              rewrite (sequal_clean_zero_equiv (sequal_sym H)) in *; discriminate end
          | econstructor; eauto
          ].
    Qed.

  
  
    (** Erasure funciton, from typed syntax (reified) to the above untyped syntax *)
    Section erase.
  
      Context `{env: Reification.Env}.
      Import Reification.KA.
  
      (** erasure function, from typed syntax to untyped syntax *)
      Fixpoint erase n m (x: X n m): regex :=
        match x with 
          | dot _ _ _ x y => RegExp.dot (erase x) (erase y)
          | plus _ _ x y => RegExp.plus (erase x) (erase y)
          | star _ x => RegExp.star (erase x)
          | zero _ _ => RegExp.zero
          | one _ => RegExp.one
          | var i => RegExp.var i
        end.
  
    End erase.


    Section faithful.

      Import Reification Classes.
      Context `{KA: KleeneAlgebra} {env: Env}.
      Notation feval := KA.eval.
        
      (* evaluation predicate *)
      Inductive eval: forall A B, regex -> X (typ A) (typ B) -> Prop :=
      | e_one: forall A, @eval A A RegExp.one 1
      | e_zero: forall A B, @eval A B RegExp.zero 0
      | e_dot: forall A B C x y x' y', @eval A B x x' -> @eval B C y y' -> @eval A C (RegExp.dot x y) (x'*y')
      | e_plus: forall A B x y x' y', @eval A B x x' -> @eval A B y y' -> @eval A B (RegExp.plus x y) (x'+y')
      | e_star: forall A x x', @eval A A x x' -> @eval A A (RegExp.star x) (x'#)
      | e_var: forall i, eval (RegExp.var i) (unpack (val i)).
      Implicit Arguments eval [].
      Local Hint Constructors eval.
    
      (** evaluation of erased terms *)
      Lemma eval_erase_feval: forall n m a, eval n m (erase a) (feval a).
      Proof. induction a; constructor; trivial. Qed.  

      (** inversion lemmas about evaluations  *)
      Lemma eval_dot_inv: forall n p u v c, eval n p (RegExp.dot u v) c -> 
        exists m, exists a, exists b, c = a*b /\ eval n m u a /\ eval m p v b.
      Proof. intros. dependent destruction H. eauto 6. Qed.
    
      Lemma eval_one_inv: forall n m c, eval n m RegExp.one c -> c [=] one (typ n) /\ n=m.
      Proof. intros. dependent destruction H. split; reflexivity. Qed.
   
      Lemma eval_plus_inv: forall n m x y z, eval n m (RegExp.plus x y) z -> 
        exists x', exists y', z=x'+y' /\ eval n m x x' /\ eval n m y y'.
      Proof. intros. dependent destruction H. eauto. Qed.
    
      Lemma eval_zero_inv: forall n m z, eval n m RegExp.zero z -> z=0. 
      Proof. intros. dependent destruction H. auto. Qed.
    
      Lemma eval_star_inv: forall n m x z, eval n m (RegExp.star x) z -> exists x', z [=] x'# /\ eval n n x x' /\ n=m. 
      Proof. intros. dependent destruction H. eexists. intuition eauto. reflexivity. Qed.

      Lemma eval_var_inv: forall n m i c, eval n m (RegExp.var i) c -> c [=] unpack (val i) /\ n=src_p (val i) /\ m=tgt_p (val i).
      Proof. intros. dependent destruction H. intuition reflexivity. Qed.
   
      Ltac eval_inversion :=
        repeat match goal with 
                 | H : eval _ _ ?x _ |- _ => eval_inversion_aux H x 
               end
        with eval_inversion_aux H x :=
          let H1 := fresh in
            match x with 
              | RegExp.dot _ _ => destruct (eval_dot_inv H) as (?&?&?&H1&?&?); subst; try rewrite H1
              | RegExp.one => destruct (eval_one_inv H) as [H1 ?]; auto; subst; apply eqd_inj in H1; subst
              | RegExp.zero => pose proof (eval_zero_inv H); subst
              | RegExp.plus _ _ => destruct (eval_plus_inv H) as (?&?&H1&?&?); auto; subst
              | RegExp.star _ => destruct (eval_star_inv H) as (?&H1&?&?); auto; subst; apply eqd_inj in H1; subst
              | RegExp.var _ => destruct (eval_var_inv H) as (H1&?&?); auto; subst; apply eqd_inj in H1; subst
            end; clear H.    
  
      (* semi-injectivity *)
      Lemma eval_type_inj_left: forall A A' B x z z', eval A B x z -> eval A' B x z' -> A=A' \/ clean x = RegExp.zero.
      Proof.
        intros A A' B x z z' H; revert A' z'; induction H; intros A' z' H';
          eval_inversion; intuition.
        
        destruct (IHeval2 _ _ H3) as [HB | Hx]. destruct HB.
         destruct (IHeval1 _ _ H2) as [HA | Hy]; auto.
         right; simpl. rewrite Hy. reflexivity.
         right; simpl. rewrite Hx. RegExp.destruct_tests; reflexivity.
        
        destruct (IHeval2 _ _ H3) as [HB | Hx]; auto.
        destruct (IHeval1 _ _ H2) as [HA | Hy]; auto.
        right; simpl. rewrite Hx, Hy. reflexivity.
      Qed.
  
      Lemma eval_type_inj_right: forall A B B' x z z', eval A B x z -> eval A B' x z' -> B=B' \/ clean x = RegExp.zero.
      Proof.
        intros A B B' x z z' H; revert B' z'; induction H; intros B' z' H';
          eval_inversion; intuition.
  
        destruct (IHeval1 _ _ H2) as [HB | Hx]. destruct HB.
         destruct (IHeval2 _ _ H3) as [HA | Hy]; auto.
         right; simpl. rewrite Hy. RegExp.destruct_tests; reflexivity.
         right; simpl. rewrite Hx. reflexivity.
         
        destruct (IHeval2 _ _ H3) as [HB | Hx]; auto.
        destruct (IHeval1 _ _ H2) as [HA | Hy]; auto.
          right; simpl. rewrite Hx, Hy. reflexivity.
      Qed.
  
      (* who is cleaned in zero is zero *)
      Lemma eval_clean_zero: forall x A B z, eval A B x z -> RegExp.is_zero (clean x) = true -> z==0.
      Proof.
        induction x; simpl; intros A B z Hz H; try discriminate; eval_inversion.
        reflexivity.
  
        case_eq (RegExp.is_zero (clean x1)); intro Hx1. 
         rewrite (IHx1 _ _ _ H1 Hx1); apply dot_ann_left.
         case_eq (RegExp.is_zero (clean x2)); intro Hx2.
          rewrite (IHx2 _ _ _ H2 Hx2); apply dot_ann_right.
          rewrite Hx1, Hx2 in H; discriminate.
  
        case_eq (RegExp.is_zero (clean x1)); intro Hx1;
        case_eq (RegExp.is_zero (clean x2)); intro Hx2;
         rewrite Hx1, Hx2, ?Hx1 in H; try discriminate.
         rewrite (IHx1 _ _ _ H1 Hx1), (IHx2 _ _ _ H2 Hx2); apply plus_idem.
  
        case_eq (RegExp.is_zero (clean x)); intro Hx; rewrite Hx in H; discriminate.
      Qed.
      
      Lemma eval_clean: forall A B x y, eval A B x y -> exists2 z, eval A B (clean x) z & y==z.
      Proof.
        intros A B x y H; induction H; simpl; try (eexists; [ eauto || fail |]); trivial.
  
        RegExp.destruct_tests.
         exists 0; auto.
         destruct IHeval1 as [z Hz Hxz]; clear IHeval2.
         rewrite Hxz, (eval_zero_inv Hz); auto with algebra.
  
         exists 0; auto.
         destruct IHeval2 as [z Hz Hyz]; clear IHeval1.
         rewrite Hyz, (eval_zero_inv Hz); auto with algebra.
  
         destruct IHeval1; destruct IHeval2; eauto with compat.
  
        RegExp.destruct_tests.
         destruct IHeval2 as [y'' Hy'' Hy]; exists y''; auto.
         destruct IHeval1 as [z Hz Hxz].
         rewrite Hxz, (eval_zero_inv Hz), Hy. auto with algebra.
  
         destruct IHeval1 as [y'' Hy'' Hy]; exists y''; auto.
         destruct IHeval2 as [z Hz Hxz].
         rewrite Hxz, (eval_zero_inv Hz), Hy. auto with algebra.
  
         destruct IHeval1; destruct IHeval2; eauto with compat.
  
        RegExp.destruct_tests.
         exists 1; auto.
         destruct IHeval as [z Hz Hxz]. rewrite Hxz. eval_inversion. apply star_zero.
         destruct IHeval as [x'' Hx'' Hx]; eauto with compat. 
      Qed.
  
  
      Lemma eval_inj: forall A B x y z, eval A B x y -> eval A B x z -> y==z.
      Proof.
        intros A B x y z H; revert z; induction H; intros; 
          eval_inversion; auto with compat. 
  
        destruct (eval_type_inj_left H0 H4) as [HB | Hx].
         destruct HB.
         rewrite (IHeval1 _ H3), (IHeval2 _ H4); reflexivity.
         rewrite (eval_clean_zero H0), (eval_clean_zero H4) by (rewrite Hx; reflexivity).
         rewrite 2 dot_ann_right; reflexivity.
      Qed.
  
  
      Lemma and_idem: forall (A: Prop), A -> A/\A.
      Proof. tauto. Qed.
    
      Ltac split_IHeval :=
        repeat match goal with 
                 | H: (forall A B x', eval A B ?x x' -> _) /\ _ ,
                   Hx: eval ?A ?B ?x ?x' |- _ => destruct (proj1 H _ _ _ Hx); clear H
                 | H: _ /\ forall A B x', eval A B ?x x' -> _  ,
                   Hx: eval ?A ?B ?x ?x' |- _ => destruct (proj2 H _ _ _ Hx); clear H
               end;
        repeat match goal with 
                 | H: (forall A B x', eval A B ?x x' -> _) 
                   /\ (forall A B y', eval A B ?y y' -> _) |- _ => destruct H
               end.
  
  
      Ltac eval_injection :=
        repeat match goal with
                 | H: eval ?A ?B ?x ?z , H': eval ?A ?B  ?x ?z' |- _ => rewrite (eval_inj H H') in *; clear H
               end.
  
      Lemma eval_sequal: forall x y, sequal x y -> forall A B x', eval A B x x' -> exists2 y', eval A B y y' & x'==y'.
      Proof.
        intros x y H.
        cut ((forall A B x', eval A B x x' -> exists2 y', eval A B y y' & x'==y')
                /\ (forall A B y', eval A B y y' -> exists2 x', eval A B x x' & y'==x')); [tauto| ].
        induction H; (apply and_idem || split); intros A B xe Hx; 
          eval_inversion; try solve [split_IHeval; eexists; [eauto; fail | eval_injection; auto with algebra ]].
  
        (* dot_distr_left *)
        destruct (eval_type_inj_left H4 H5) as [HB | Hz]; [ destruct HB | rewrite Hz in H; discriminate ].
        eexists; eauto.
        rewrite (eval_inj H4 H5); symmetry; apply dot_distr_left.
  
        (* dot_distr_right *)
        destruct (eval_type_inj_right H2 H3) as [HB | Hz]; [ destruct HB | rewrite Hz in H; discriminate ].
        eexists; eauto.
        rewrite (eval_inj H3 H2); symmetry; apply dot_distr_right.
  
        (* star_destruct_left lr *)
        eexists; eauto. eval_injection.
        apply star_destruct_left; unfold leq. 
        destruct (proj1 IHsequal _ _ (x0*x1+x1)) as [ y1 ? Hy1 ]; auto.
        rewrite Hy1. eval_injection. reflexivity.
  
        (* star_destruct_left rl *)
        destruct (proj2 IHsequal _ _ _ Hx) as [ x' Hx' ].
        eval_inversion.
        destruct (eval_type_inj_left H4 H6) as [HB | Hz]; [ destruct HB | rewrite Hz in H; discriminate ].
        eexists; eauto. eval_injection.
        symmetry; apply star_destruct_left; unfold leq.
        auto.
  
        (* star_destruct_right lr *)
        eexists; eauto. eval_injection.
        apply star_destruct_right; unfold leq. 
        destruct (proj1 IHsequal _ _ (x3*x0+x3)) as [ y1 ? Hy1 ]; auto.
        rewrite Hy1. eval_injection. reflexivity.
  
        (* star_destruct_left rl *)
        destruct (proj2 IHsequal _ _ _ Hx) as [ x' Hx' ].
        eval_inversion.
        destruct (eval_type_inj_right H4 H5) as [HB | Hz]; [ destruct HB | rewrite Hz in H; discriminate ].
        eexists; eauto. eval_injection.
        symmetry; apply star_destruct_right; unfold leq. 
        auto.
  
        (* sequal_trans *)
        split_IHeval; eauto using Graph.equal_trans.
        split_IHeval; eauto using Graph.equal_trans.
      Qed.
      
          
      (** untyping theorem  *)
      Theorem equal_eval: forall x' y', RegExp.equal x' y'-> 
        forall A B x y, eval A B x' x -> eval A B y' y -> x==y.
      Proof.
        intros x' y' H A B x y Hx Hy.
        destruct (eval_clean Hx) as [x1 Hx1 Hx1'].
        destruct (eval_clean Hy) as [y1 Hy1 Hy1'].
        destruct (eval_sequal (equal_to_sequal H) Hx1) as [y2 Hy2 Hy2'].
        rewrite Hx1', Hy1', Hy2'.
        rewrite (eval_inj Hy2 Hy1).
        reflexivity.
      Qed.
    
      (* other formulation, using the intermediate reification syntax *)
      Theorem erase_faithful: forall n m (a b: KA.X n m), 
        RegExp.equal (erase a) (erase b) -> feval a == feval b.
      Proof. intros. eapply equal_eval; eauto using eval_erase_feval. Qed.
  
      (* TMP: for the semiring_normalize tactic *)
      Lemma normalizer {n} {m} {R} `{T: Transitive (Classes.X (typ n) (typ m)) R} `{H: subrelation _ (equal _ _) R} 
        norm (Hnorm: forall x, RegExp.equal x (norm x)): 
        forall a b a' b',
          (* utiliser le prédicat d'évaluation permet d'éviter de repasser en OCaml 
             pour inventer le témoin typé... par contre, le terme de preuve grossit. *)
          (let na := norm (erase a) in eval n m na a') ->
          (let nb := norm (erase b) in eval n m nb b') ->
          R a' b' -> R (feval a) (feval b).
      Proof.
        intros until b'; intros Ha Hb Hab.
        transitivity a'.
         apply H. eapply equal_eval; eauto using eval_erase_feval. 
         rewrite Hab.
         apply H. symmetry. eapply equal_eval; eauto using eval_erase_feval. 
      Qed.

    End faithful.
    End protect.
  End Untype.
End RegExp.
Import RegExp.

Ltac kleene_normalize_ Hnorm :=
  let t := fresh "t" in
  let e := fresh "e" in
  let l := fresh "l" in
  let r := fresh "r" in
  let x := fresh "x" in
  let solve_eval :=
    intro x; vm_compute in x; subst x;
      repeat econstructor;
        match goal with |- Untype.eval (var ?i) _ => eapply (Untype.e_var (env:=e) i) end
  in
    kleene_reify; intros t e l r;
      eapply (Untype.normalizer Hnorm); 
        [ solve_eval | 
          solve_eval |
            compute [t e Reification.unpack Reification.val Reification.typ
              Reification.tgt Reification.src Reification.tgt_p Reification.src_p
              Reification.sigma_get Reification.sigma_add Reification.sigma_empty 
              FMapPositive.PositiveMap.find FMapPositive.PositiveMap.add 
              FMapPositive.PositiveMap.empty ] ];
        clear t e l r.

(** tactic to clean zeros in Kleene algebra expressions *)
Ltac kleene_clean_zeros := kleene_normalize_ Clean.correct.
  
(*begintests
  Section test.
    Context `{KA: KleeneAlgebra}.
    Goal forall A (a b: X A A), (a*0)#*b == b+0*a#+b*0#.
      intros. kleene_clean_zeros. semiring_reflexivity. 
    Abort.
    Goal forall A (a b: X A A), (a*0)# <== b+0*a#+0#.
      intros. kleene_clean_zeros. semiring_reflexivity. 
    Abort.
  End test.
endtests*)
