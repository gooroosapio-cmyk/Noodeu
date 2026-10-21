-- Élargit les règles de validation pour accueillir les identifiants N2-xxx, les nouveaux moteurs et le mode création.
-- Aucune ligne n'est modifiée ni supprimée : seules les règles de vérification sont remplacées par des versions plus larges.
alter table public.games drop constraint if exists games_id_check;
alter table public.games add constraint games_id_check check (id ~ '^[A-Za-z0-9-]{2,60}$');
alter table public.games drop constraint if exists games_mechanic_check;
alter table public.games add constraint games_mechanic_check check (mechanic ~ '^[a-z_]{2,40}$');
alter table public.games drop constraint if exists games_style_check;
alter table public.games add constraint games_style_check check (style in ('echange', 'duel', 'cooperation', 'creation'));
alter table public.game_cards drop constraint if exists game_cards_kind_check;
alter table public.game_cards add constraint game_cards_kind_check check (kind in ('word', 'question'));
