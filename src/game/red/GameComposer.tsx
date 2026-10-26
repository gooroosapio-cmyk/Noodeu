import { useEffect, useState, type FormEvent } from "react";
import { Icon } from "../../components/ui";
import { draftKey } from "../../duo/Chat";
import { useDuo } from "../../duo/DuoProvider";
import { errorMessage } from "../../lib/errors";
import { useOnline } from "../../lib/useOnline";

/** Pied de jeu (V7) : vraie saisie et envoi explicite vers la conversation du duo, à la place de la navigation.
 *  Le focus ouvre la conversation intégrée au jeu ; le brouillon est le même que celui du chat (stockage d'onglet
 *  déjà en place, par duo) et l'état de jeu n'est jamais réinitialisé. Ce champ n'envoie rien au jeu : une réponse
 *  de jeu reste dans le champ de réponse du jeu, distinct et libellé. */
export function GameComposer({ onOpen }: { onOpen: () => void }) {
  const { active, sendMessage, chatUnread } = useDuo();
  const online = useOnline();
  const coupleId = active?.id ?? null;
  const partner = active?.partner?.name || "ton duo";
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    if (!coupleId) return;
    try { setDraft(sessionStorage.getItem(draftKey(coupleId)) ?? ""); } catch { setDraft(""); }
  }, [coupleId]);
  if (!coupleId) return null;

  async function submit(e: FormEvent) {
    e.preventDefault();
    const body = draft.trim();
    if (!body) { onOpen(); return; }
    setDraft("");
    try { sessionStorage.setItem(draftKey(coupleId!), ""); } catch { /* stockage indisponible */ }
    const res = await sendMessage(body);
    if (!res.ok) { setDraft(body); setError(errorMessage(res.error)); } else setError(null);
  }

  return (
    <form className="v7-game-composer" onSubmit={submit} aria-label={`Conversation avec ${partner}`}>
      {error && <p className="v7-game-composer__error" role="alert">{error}</p>}
      <label htmlFor="game-chat-input" className="sr-only">Message à {partner}{chatUnread ? `, ${chatUnread} non lus` : ""}</label>
      <input id="game-chat-input" className="v7-game-composer__input" type="text" autoComplete="off" enterKeyHint="send"
        placeholder={`Écrire à ${partner}…`} value={draft} maxLength={1000} onFocus={onOpen}
        onChange={(e) => { setDraft(e.target.value); try { sessionStorage.setItem(draftKey(coupleId), e.target.value); } catch { /* stockage indisponible */ } }} />
      {chatUnread > 0 && <span className="v7-game-composer__badge" aria-hidden="true">{chatUnread > 9 ? "9+" : chatUnread}</span>}
      <button type="submit" className="v7-game-composer__send" disabled={!online && Boolean(draft.trim())}
        aria-label={draft.trim() ? `Envoyer le message à ${partner}` : `Ouvrir la conversation avec ${partner}`}>
        <Icon name="send" size={20} />
      </button>
    </form>
  );
}
