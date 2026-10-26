import { useEffect, useRef, useState } from "react";

// La clé historique reste compatible ; la révision ne contient aucune donnée privée.
export const draftKey = (coupleId: string) => `noodeu.chat.draft.${coupleId}`;
const ownerKey = (coupleId: string) => `${draftKey(coupleId)}.owner`;
const revisionKey = (coupleId: string) => `${draftKey(coupleId)}.revision`;
const DRAFT_CHANGED = "noodeu:chat-draft";
export function readChatDraft(coupleId: string | null, userId: string | null) {
  try {
    if (!coupleId || !userId) return "";
    const owner = sessionStorage.getItem(ownerKey(coupleId));
    if (owner && owner !== userId) return "";
    return sessionStorage.getItem(draftKey(coupleId)) ?? "";
  }
  catch { return ""; }
}
export function writeChatDraft(coupleId: string, body: string, userId: string) {
  try {
    const revision = crypto.randomUUID();
    // owner est un UUID : cette sentinelle bloque toute lecture pendant une écriture partielle.
    // Ne publier le propriétaire qu'après le texte ET sa révision ; aucune suppression n'est nécessaire.
    sessionStorage.setItem(ownerKey(coupleId), "pending");
    sessionStorage.setItem(draftKey(coupleId), body);
    sessionStorage.setItem(revisionKey(coupleId), revision);
    sessionStorage.setItem(ownerKey(coupleId), userId);
    window.dispatchEvent(new CustomEvent(DRAFT_CHANGED, { detail: coupleId }));
    return revision;
  } catch { return null; }
}
/** Un échec ancien ne remplace jamais une saisie plus récente, même déjà envoyée ou vidée. */
export function restoreChatDraft(coupleId: string, revision: string | null, body: string, userId: string) {
  try {
    if (!revision || sessionStorage.getItem(ownerKey(coupleId)) !== userId || sessionStorage.getItem(revisionKey(coupleId)) !== revision) return false;
    return writeChatDraft(coupleId, body, userId) !== null;
  } catch { return false; }
}
/** Appelée dans un composant remonté par utilisateur/duo. Partage uniquement le brouillon de ce duo. */
export function useChatDraft(coupleId: string | null, userId: string | null) {
  const [draft, setValue] = useState(() => readChatDraft(coupleId, userId));
  const generation = useRef(0), alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    // Migration locale de la clé historique : son contenu reste intact pour le compte connecté.
    try { if (coupleId && userId && !sessionStorage.getItem(ownerKey(coupleId))) sessionStorage.setItem(ownerKey(coupleId), userId); } catch { /* stockage indisponible */ }
    const changed = (event: Event) => {
      if ((event as CustomEvent<string>).detail === coupleId) { generation.current++; setValue(readChatDraft(coupleId, userId)); }
    };
    window.addEventListener(DRAFT_CHANGED, changed);
    return () => { alive.current = false; window.removeEventListener(DRAFT_CHANGED, changed); };
  }, [coupleId, userId]);
  function setDraft(body: string) {
    generation.current++;
    setValue(body);
    const revision = coupleId && userId ? writeChatDraft(coupleId, body, userId) : null;
    return { revision, generation: generation.current };
  }
  function restoreDraft(body: string, stamp: { revision: string | null; generation: number }, memoryOnly = false) {
    if (!coupleId || !userId) return;
    if (!memoryOnly && stamp.revision) {
      restoreChatDraft(coupleId, stamp.revision, body, userId);
      return;
    }
    // Stockage indisponible : reprise en mémoire uniquement dans la même instance et sans saisie nouvelle.
    if (alive.current && generation.current === stamp.generation) { generation.current++; setValue(body); }
  }
  return [draft, setDraft, restoreDraft] as const;
}
