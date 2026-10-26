-- Comptes réels (phase de test) : optimisation des contrôles d'accès, sans changement de règle.
-- 1. Index sur les colonnes utilisées par chaque contrôle d'appartenance (is_member, my_couple_id,
--    shares_couple_with) et par la suppression de compte (mise à NULL des références).
-- 2. Règles « propriétaire » réécrites pour évaluer auth.uid() une seule fois par requête (même effet).
-- Aucune donnée modifiée.

create index if not exists couple_members_user on public.couple_members(user_id);
create index if not exists session_prefs_user on public.session_prefs(user_id);
create index if not exists current_duo_couple on private.current_duo(couple_id);

alter policy favorites_own on public.item_favorites
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
alter policy later_own on public.later_items
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
alter policy feedback_own on public.item_feedback
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
