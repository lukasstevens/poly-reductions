theory VC_To_Fas                                                          
  imports  "../Reductions"
           FAS_Definition
           "../Three_Sat_To_Set_Cover" (* vertex cover is defined here *)
begin

(* helper lemmas *)         
lemma card_image_Collect:
  assumes  "inj_on f {x. P x} "
  shows    "card {f x|x. P x} = card {x. P x}"
  by (simp add: assms card_image setcompr_eq_image)

lemma hd_distinct_not_in_tl:
  assumes "distinct xs"
  shows "hd xs \<notin> set (tl xs)"
  using assms by (cases xs) auto

lemma fin_f_doubleton_ss:
  assumes "finite E"
  shows "finite {f u v| u v. {u, v} \<in> E}"
  using assms  
proof (induction E rule: finite_induct)
  case empty
  then show ?case by force
next
  case (insert x F)
  have split: "{f u v |u v. {u, v} \<in> insert x F} =
               {f u v |u v. {u, v} = x} \<union>
               {f u v |u v. {u, v} \<in>  F}" by auto
  then show ?case 
  proof (cases "\<exists>u v. x = {u, v}")
    case True
    then obtain u v where uv_def: "x = {u, v}" by blast
    then have "{f u v |u v. {u, v} = x} = {f u v, f v u}"
      by (subst uv_def,subst doubleton_eq_iff,blast)
    then show ?thesis using split insert by auto
  next
    case False
    then have "{f u v |u v. {u, v} = x} = {}" by blast
    then show ?thesis using split insert by simp
  qed
qed

(* graphs *)

lemma (in wf_digraph) awalk_verts_appendI:
  assumes "awalk u (p1 @ p2) v"
          "w = last (awalk_verts u p1)"
  shows "awalk_verts u (p1 @ p2) = awalk_verts u p1 @ tl (awalk_verts w p2)"
  using awalk_verts_append assms 
  by blast

(** this is the same definition as cycle but specifies the start vertex **)
definition (in pre_digraph) cycle_start   where
  "cycle_start p x \<equiv> awalk x p x  \<and> distinct (tl (awalk_verts x p)) \<and> p \<noteq> []"


lemma (in pre_digraph) tl_awalk_verts:
  shows  "tl (awalk_verts  x (e # es)) = awalk_verts (head G e) es"
  by fastforce


lemma (in wf_digraph) rotate1_cycle_start:
  assumes  "cycle_start (e#es) x"
  shows    "cycle_start (es@[e]) (head G e)" 
proof -
  let ?y = "head G e"
  have *: "awalk ?y (es @ [e]) ?y"  using assms unfolding cycle_start_def 
    by (intro awalk_appendI[where ?v = "tail G e"] arc_implies_awalk)
       (auto simp add: awalk_Cons_iff)
  moreover then have **: "awalk_verts ?y (es @ [e]) = awalk_verts ?y es @ tl (awalk_verts x [e])"
    using assms by (intro awalk_verts_appendI)
                   (auto simp add: cycle_start_def awalk_Cons_iff)
  moreover have "distinct (tl (awalk_verts ?y (es @ [e])))"
  proof -
    have "distinct (awalk_verts ?y es)"  using assms unfolding cycle_start_def by simp
    moreover then have "?y \<notin> set (tl (awalk_verts ?y es))" 
      using * hd_distinct_not_in_tl by fastforce
     ultimately show ?thesis using **  by (simp add: distinct_tl)
  qed
  then show ?thesis unfolding cycle_start_def 
    using calculation by fastforce
qed


(** define the reduction **)
  
definition H where
  "H E \<equiv> \<lparr> verts = (\<Union>E) \<times> {0::nat,1},
           arcs = {((u, 0::nat), (u, 1::nat)) |u. u \<in> \<Union> E }
                \<union> {((u, 1::nat), (v, 0::nat)) |u v. {u,v} \<in> E},
           tail = fst, head = snd \<rparr>"

definition MALFORMED_GRAPH where
    "MALFORMED_GRAPH  =  \<lparr> verts = {},
                           arcs = {((undefined, 0),(undefined, 0))},
                           tail = fst, head = fst \<rparr>"
lemma isMALFORMED_GRAPH:
     "\<not> wf_digraph MALFORMED_GRAPH"
  by (simp add: MALFORMED_GRAPH_def wf_digraph_def)

definition vc_to_fas where
  "vc_to_fas \<equiv> \<lambda>(E,K). (if K \<le> card (\<Union>E) \<and> (\<forall>e \<in> E. card e = 2)
                        then H E else MALFORMED_GRAPH, K)"


(** properties of H and its cycles **)

lemma wf_H: "wf_digraph (H E)"
  unfolding wf_digraph_def H_def 
  using insert_commute by auto

(* given a cycle starting at (u,b),
   gives a cycle starting at next node *)
lemma cycle_start_at_next:
  assumes "pre_digraph.cycle_start (H E) (e#es) (u,b)"
  shows   "\<exists>v e' es'. e = ((u,b),(v,1 - b))
         \<and> (b = 0 \<longrightarrow> (u = v))
         \<and> (e' \<in> set (e'#es'))
         \<and> set (e#es) = set (e'#es')
         \<and> pre_digraph.cycle_start (H E) (e'#es') (v,1 - b)"
proof -
  have e_edge: "e \<in> arcs (H E)" 
    by (meson assms pre_digraph.cycle_start_def wf_digraph.awalk_Cons_iff wf_H)
  have "tail (H E) e = (u,b)" 
    using assms pre_digraph.cas_simp pre_digraph.awalk_def
    unfolding pre_digraph.cycle_start_def by fastforce
  then obtain v b2 where e_content: "e = ((u,b),(v,b2))" "head (H E) e = (v, b2)"      
    using assms unfolding pre_digraph.cycle_start_def pre_digraph.awalk_def H_def
    by auto
  moreover then have "b2 = 1 - b" using e_edge unfolding H_def
    by (cases b) auto
  moreover then have "pre_digraph.cycle_start (H E) (es @ [e]) (v,1 - b)"
    using wf_digraph.rotate1_cycle_start[OF wf_H] e_content assms 
    unfolding pre_digraph.cycle_start_def by metis
  moreover have "b = 0 \<Longrightarrow> u = v"
    using e_content e_edge unfolding H_def  by force
  moreover obtain e' es' where e'_def: "e'#es' = es@[e]"
    by (cases "es@[e]") auto
  ultimately show ?thesis 
    by (intro exI[of _ v] exI[of _ e']  exI[of _ es'] conjI)
       (meson list.set_intros | simp)+
qed


lemma cycle_strcture:
  assumes "pre_digraph.cycle (H E) p"
  shows   "\<exists>u v. ((u, 1),(v,0)) \<in> set p
                \<and> ((u, 0),(u, 1)) \<in> set p
                \<and> ((v, 0), (v, 1)) \<in> set p"
proof -
  obtain u' b' e' es' where  c_start': "pre_digraph.cycle_start (H E) (e'#es') (u',b')"
                                   and "set p = set (e' # es')"
    using assms unfolding pre_digraph.cycle_def pre_digraph.cycle_start_def by (cases p) auto
  then obtain u e es where c_start: "pre_digraph.cycle_start (H E) (e#es) (u,0)"
                                and "set p = set (e # es)"
    using cycle_start_at_next[OF c_start'] by (cases b') auto
  then show ?thesis 
      apply -
      apply (drule cycle_start_at_next, elim exE, (erule conjE)+) 
      (* how do I apply something 3 times? *)
      apply (drule cycle_start_at_next, elim exE, (erule conjE)+) 
      apply (drule cycle_start_at_next, elim exE, (erule conjE)+) 
      using list.set_intros[of e es] by (auto simp del:set_simps)  
qed

(** correctness proof **)

lemma vc_to_fas_soundness:
  assumes "(E, k) \<in> vertex_cover"
  shows "(vc_to_fas (E, k)) \<in> feedback_arc_set"
proof -
  obtain V_C where finE: "finite E" and card2: "(\<forall>e\<in>E. card e = 2)" 
    and "V_C \<subseteq> \<Union> E" and "k \<le> card (\<Union> E)" 
    and "card V_C \<le> k"  and "is_vertex_cover E V_C"
    using assms unfolding vertex_cover_def ugraph_def by blast
  define S where "S \<equiv> { ((u, 0::nat), (u, 1::nat)) |u. u \<in> V_C }"
  have "(H E, k) \<in> feedback_arc_set"
  proof (intro feedback_arc_set_cert[of S])

    show "S \<subseteq> arcs (H E)" using \<open>V_C \<subseteq> \<Union> E\<close>
      unfolding H_def S_def by fastforce
    
    have "finite (\<Union> E)" using finE card2 card.infinite
      by (intro finite_Union) fastforce+
    then show "fin_digraph (H E)"  
      using finE wf_H unfolding H_def 
      by (intro wf_digraph.fin_digraphI) (auto simp add: Union_eq fin_f_doubleton_ss)
     
    have "card S = card {x. x \<in> V_C}" unfolding S_def
      by (intro card_image_Collect, simp add: inj_on_def)  
    then show "card S \<le> k"  using \<open>card V_C \<le> k\<close> by simp

    show "\<forall> p. pre_digraph.cycle (H E) p \<longrightarrow> (\<exists> e \<in> S. e \<in> set p)"
    proof (intro allI impI)
      fix p assume p_cycle: "pre_digraph.cycle (H E) p"
      then obtain u v  where uv_def: "((u, 1), v, 0) \<in> set p"
                                     "((u, 0), u, 1) \<in> set p" 
                                     "((v, 0), v, 1) \<in> set p" 
        using cycle_strcture by blast
      then have "((u, 1), (v, 0)) \<in> arcs (H E)" 
        by (meson p_cycle pre_digraph.awalk_def pre_digraph.cycle_def subsetD)
      then have "{u, v} \<in> E" unfolding H_def by simp
      then have  "(u \<in>  V_C) \<or> (v \<in> V_C)" 
        using \<open>is_vertex_cover E V_C\<close> is_vertex_cover_def 
        by fastforce
      then show "(\<exists>e\<in>S. e \<in> set p)" using S_def uv_def by blast   
    qed 
  qed
  then show ?thesis
    unfolding  vc_to_fas_def 
    by (simp add: \<open>k \<le> card (\<Union> E)\<close> card2)
qed


lemma vc_to_fas_completeness:
  assumes "(vc_to_fas (E, k)) \<in> feedback_arc_set"
  shows "(E, k) \<in> vertex_cover"
proof (cases "k \<le> card (\<Union>E) \<and> (\<forall>e \<in> E. card e = 2)")
  case True
  obtain S where S_def: "S \<subseteq> arcs (H E)" "card S \<le> k" "fin_digraph (H E)"
    "\<forall> p. pre_digraph.cycle (H E) p \<longrightarrow> (\<exists> e \<in> S. e \<in> set p)"
    using assms True 
    unfolding feedback_arc_set_def vc_to_fas_def by auto
  
  define V where V_def: "V \<equiv>  (fst \<circ> fst) ` S"

  have V_def2: "V = {u. ((u, 0), (u, 1)) \<in> S }
                  \<union> {u |u v. ((u, 1), (v, 0)) \<in> S}"
  proof -
    have *: "S = {((u, 0), (u, 1)) |u.   ((u, 0), (u, 1)) \<in> S}
               \<union> {((u, 1), (v, 0)) |u v. ((u, 1), (v, 0)) \<in> S}"
      using \<open>S \<subseteq> arcs (H E)\<close> unfolding H_def by auto  
    show ?thesis unfolding V_def
      by (subst *, subst image_Un) force
  qed

  have "finite E" 
    using  fin_digraph.finite_verts[OF \<open>fin_digraph (H E)\<close>]
           finite_UnionD finite_cartesian_productD1 
    unfolding H_def by auto
  then have "ugraph E" 
    by (simp add: True ugraph_def) 

  moreover have "V \<subseteq> \<Union> E"
    using \<open>S \<subseteq> arcs (H E)\<close> V_def2 unfolding H_def by auto
  moreover have "k \<le> card (\<Union> E)" using True by auto
  moreover have "card V \<le> k" unfolding V_def
    using card_image_le \<open>card S \<le> k\<close>  dual_order.trans   
      finite_subset[OF \<open>S \<subseteq> arcs (H E)\<close> fin_digraph.finite_arcs[OF \<open>fin_digraph (H E)\<close>]] 
    by fast
  moreover have "is_vertex_cover E V"
  proof (unfold is_vertex_cover_def, intro ballI)
    fix e assume e_def: "e \<in> E"
    then obtain u v where uv_def: "e = {u, v}" 
      using \<open>ugraph E\<close> unfolding ugraph_def  by (meson card_2_iff)  
    then show "\<exists> v \<in> V. v \<in> e" 
    proof -
      let ?cycle = "if u = v then [((u, 0), (u, 1)), ((u, 1), (u, 0))]
                             else [((u, 0), (u, 1)), ((u, 1), (v, 0)),
                                   ((v, 0), (v, 1)), ((v, 1), (u, 0))]"
      have "pre_digraph.cycle_start (H E) ?cycle (u,0)" 
        unfolding pre_digraph.cycle_start_def pre_digraph.awalk_def H_def  
        using uv_def e_def 
        by (auto simp add: insert_commute pre_digraph.cas.simps pre_digraph.awalk_verts.simps)       
      then have "(\<exists> e \<in> S. e \<in> set ?cycle)"
        unfolding pre_digraph.cycle_start_def 
        using S_def pre_digraph.cycle_def by blast
      then show ?thesis using V_def2 uv_def 
        by (cases "u = v") (simp,auto)
    qed
  qed
  ultimately show ?thesis unfolding vertex_cover_def by blast
next
  case False
  have "(MALFORMED_GRAPH,k) \<notin> feedback_arc_set" 
    unfolding feedback_arc_set_def 
    using fin_digraph_def isMALFORMED_GRAPH by fastforce
  then show ?thesis using assms False  
    unfolding vc_to_fas_def by auto
qed  

theorem is_reduction_vc_to_fas:
  "is_reduction vc_to_fas vertex_cover feedback_arc_set"
  unfolding is_reduction_def 
  using vc_to_fas_soundness vc_to_fas_completeness
  by fast

end