-- Remise à zéro de la base d'activités (décision du 23 octobre 2026), avant l'import d'une nouvelle base.
-- Effacé : toutes les parties (réponses, manches, secrets, coups, messages, souvenirs gardés), les notifications
-- de proposition de partie, les favoris, les activités avec leurs règles, cartes et niveaux.
-- Conservé : les familles (game_categories), le journal des imports et le code des moteurs de jeu.

delete from public.notifications where type = 'game_proposed' or data ? 'session_id' or data ? 'game_id';

-- Les parties emportent en cascade joueurs, manches, réponses, messages, préférences, secrets et coups.
delete from public.game_sessions;

-- games.current_version pointe vers game_versions, qui pointe vers games : on coupe le lien avant d'effacer.
-- Les versions publiées sont protégées contre toute modification : protection suspendue le temps de la remise à zéro.
update public.games set current_version = null;
alter table public.game_versions disable trigger game_versions_immutable;
delete from public.games;            -- emporte versions, cartes et favoris
alter table public.game_versions enable trigger game_versions_immutable;

delete from public.content_banks;

insert into public.catalogue_imports (content_version, report)
values ('purge', jsonb_build_object('partie', 'remise à zéro', 'section', 'base d''activités effacée'));
