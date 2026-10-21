# Tests SQL

- `slice1_security_and_game.sql` : suite complète (invitations, partie, confidentialité, chat, duos A–B / A–C,
  reprise, codes régénérés, photos). Locale via `local_shim.sql`, ou dans l'éditeur SQL Supabase.
- Chaque fichier s'exécute dans une transaction annulée (`rollback`) : aucune donnée ne reste.

Dernière exécution sur le projet Supabase : 21 octobre 2026, tous les tests passés (scénarios duo exécutés en ligne
dans une version autonome, mêmes assertions).
