/** Aucun contenu de réponse : seulement l'identifiant d'une proposition de salon. */
export interface GameProposal {
  id: string; type: string; couple_id: string | null; read_at: string | null;
  created_at: string; data: Record<string, unknown>;
}
export function proposalKey(n: GameProposal): string | null {
  const id = n.data.session_id;
  return n.type === 'game_proposed' && typeof id === 'string' && /^[0-9a-f-]{36}$/i.test(id)
    && n.couple_id ? `${n.couple_id}:${id}` : null;
}
export function nextProposal<T extends GameProposal>(list: T[], activeDuoIds: string[], dismissed: Set<string>, now: number): T | undefined {
  return list.find(n => {
    const key = proposalKey(n), age = now - Date.parse(n.created_at);
    return key && !n.read_at && activeDuoIds.includes(n.couple_id!) && !dismissed.has(key)
      && Number.isFinite(age) && age >= -60_000 && age < 86_400_000;
  });
}
