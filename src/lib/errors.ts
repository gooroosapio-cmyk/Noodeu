// Traduction des codes d'erreur renvoyés par la base en messages compréhensibles.
const messages: Record<string, string> = {
  network: "Le réseau ne répond pas. Vérifie ta connexion puis réessaie.",
  unexpected: "Un souci inattendu est survenu. Réessaie dans un instant.",
  not_authenticated: "Ta session a expiré. Reconnecte-toi.",
  invalid_code: "Ce code ne correspond à aucune invitation. Vérifie les 8 caractères.",
  own_invitation: "C'est ton propre code : partage-le avec la personne que tu invites.",
  revoked: "Cette invitation a été annulée. Demande un nouveau code.",
  already_used: "Cette invitation a déjà été utilisée.",
  expired: "Cette invitation a expiré. Demande un nouveau code à la personne qui t'invite.",
  you_are_already_paired: "Tu as déjà un duo actif. Termine-le depuis l'Espace avant d'en commencer un autre.",
  inviter_already_paired: "La personne qui t'invite a déjà un duo actif.",
  already_paired: "L'un de vous a déjà un duo actif.",
  too_many_attempts: "Trop d'essais d'affilée. Patiente un quart d'heure avant de réessayer.",
  pending_request_elsewhere: "Tu as déjà une demande en attente. Annule-la avant d'en envoyer une autre.",
  no_pending_request: "Aucune demande en attente.",
  no_couple: "Ce jeu se joue à deux : invite d'abord quelqu'un.",
  game_unavailable: "Ce jeu n'est pas disponible pour le moment.",
  content_not_enabled: "Ce jeu demande que vous ayez tous les deux accepté les contenus intimes.",
  session_in_progress: "Une autre partie est déjà ouverte.",
  session_not_found: "Cette partie est introuvable ou ne te concerne pas.",
  not_in_lobby: "La partie a déjà commencé.",
  invalid_settings: "Ce réglage n'est pas possible.",
  paused: "La partie est en pause.",
  not_playing: "La partie n'est plus en cours.",
  stale_round: "La partie a avancé entre-temps : l'écran a été mis à jour.",
  already_revealed: "Les réponses ont déjà été révélées.",
  already_submitted: "Ta réponse était déjà enregistrée.",
  previous_step_missing: "Termine d'abord l'étape précédente.",
  invalid_answer: "Choisis exactement le nombre de mots demandé.",
  not_enough_cards: "Ce jeu n'a pas assez de cartes publiées pour l'instant.",
  session_closed: "Ce duo est archivé : la discussion est en lecture seule.",
  invalid_message: "Ton message est vide ou trop long (1000 caractères maximum).",
  not_ended: "La partie n'est pas encore terminée.",
  confirmation_required: "Confirmation manquante.",
};

export function errorMessage(code: string | undefined | null): string {
  return (code && messages[code]) || messages.unexpected;
}

// Messages de Supabase Auth (anglais) les plus fréquents.
export function authErrorMessage(message: string): string {
  if (/Invalid login credentials/i.test(message)) return "E-mail ou mot de passe incorrect.";
  if (/Email not confirmed/i.test(message)) return "Confirme d'abord ton adresse e-mail grâce au lien reçu.";
  if (/already registered|already been registered/i.test(message)) return "Un compte existe déjà avec cette adresse.";
  if (/Password should be|weak password/i.test(message)) return "Ce mot de passe est trop faible : 8 caractères minimum.";
  if (/rate limit|too many/i.test(message)) return "Trop de tentatives. Patiente quelques minutes.";
  if (/fetch|network/i.test(message)) return messages.network;
  return "La connexion n'a pas abouti. Réessaie dans un instant.";
}
