-- G02 « Je n'ai jamais » : libellés exacts du kit premium V4 (les identifiants experienced/never ne changent pas).
-- Les parties déjà commencées gardent la carte copiée au tirage.
update public.content_banks
   set value = jsonb_set(value, '{options}', '[{"id":"experienced","text":"Je l’ai déjà fait"},{"id":"never","text":"Je ne l’ai jamais fait"}]'::jsonb)
 where bank = 'conv_never'
   and value -> 'options' @> '[{"id":"experienced"},{"id":"never"}]'::jsonb;
