import { useEffect, useRef, useState, type FormEvent } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { errorMessage } from "../lib/errors";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { Avatar } from "../components/Avatar";
import { Alert, Icon, Sheet } from "../components/ui";
import type { ChatMessage } from "../lib/types";
import { useDuo } from "./DuoProvider";

function draftKey(coupleId: string) {
  return `noodeu.chat.draft.${coupleId}`;
}

/** Bulle flottante : ouvre la discussion avec la personne du duo actif. */
export function ChatLauncher({ onOpen, withNav = true }: { onOpen: () => void; withNav?: boolean }) {
  const { chatUnread } = useDuo();
  const launcher = useRef<HTMLButtonElement>(null);
  const [position, setPosition] = useState<{ left: number; top: number; headerSlot?: boolean }>();
  useEffect(() => {
    let frame = 0;
    let reserveHeader = false;
    function place() {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const button = launcher.current;
        if (!button || document.querySelector('[role="dialog"]')) return;
        const box = button.getBoundingClientRect();
        const header = document.querySelector('.session-toolbar');
        const headerPosition = () => {
          const r = header!.getBoundingClientRect();
          return { left: Math.min(innerWidth - box.width - 16, r.right - box.width - 12), top: r.top + Math.max(12, parseFloat(getComputedStyle(header!).paddingTop) || 0), headerSlot: true };
        };
        if (reserveHeader && header) {
          const next = headerPosition();
          setPosition(old => old?.left === next.left && old?.top === next.top && old?.headerSlot ? old : next);
          return;
        }
        const edge = Math.max(16, (innerWidth - 632) / 2 + 16);
        const viewportTop = visualViewport?.offsetTop ?? 0;
        const viewportBottom = viewportTop + (visualViewport?.height ?? innerHeight);
        const floor = Math.min(viewportBottom, withNav ? document.querySelector('.nav')?.getBoundingClientRect().top ?? viewportBottom : viewportBottom);
        const main = document.querySelector('main');
        const ceiling = Math.max(viewportTop + 8, main?.getBoundingClientRect().top ?? 72);
        const clippingParents = new Map<Element, { rect: DOMRect; x: boolean; y: boolean }>();
        const clip = (r: DOMRect, element: Element | null) => {
          let left = r.left, right = r.right, top = r.top, bottom = r.bottom;
          // Le texte hors d'une région défilable n'occupe pas l'écran. Respecter
          // tous les ancêtres, sinon une longue question repousse le chat et les CTA.
          for (let parent = element; parent; parent = parent.parentElement) {
            let bounds = clippingParents.get(parent);
            if (!bounds) {
              const style = getComputedStyle(parent);
              bounds = { rect: parent.getBoundingClientRect(), x: /^(auto|scroll|hidden|clip)$/.test(style.overflowX), y: /^(auto|scroll|hidden|clip)$/.test(style.overflowY) };
              clippingParents.set(parent, bounds);
            }
            if (bounds.x) { left = Math.max(left, bounds.rect.left); right = Math.min(right, bounds.rect.right); }
            if (bounds.y) { top = Math.max(top, bounds.rect.top); bottom = Math.min(bottom, bounds.rect.bottom); }
          }
          return new DOMRect(left, top, Math.max(0, right - left), Math.max(0, bottom - top));
        };
        // Une grille reste une zone protégée même en lecture seule (cases rendues en spans).
        // Une grille dense peut ne laisser aucune place parmi quatre positions fixes.
        // On cherche le bord libre sur toute la hauteur, sans dock ni espace fixe ajouté.
        const controls = Array.from(document.querySelectorAll('main a, main button, main input, main select, main textarea, main label, main img, main .board-zoom, main .astra-overview, main .astra-ttt, main .pig-tray, main .hm-board, main .hm-slots, main .q-answer, main .reveal, main .question-reading, main .pb-head, .session-toolbar a, .session-toolbar button')).filter((el) => el !== button).map((el) => clip(el.getBoundingClientRect(), el.parentElement)).filter((r) => r.width && r.height);
        const textRects: DOMRect[] = [];
        for (const region of [main, header]) {
          if (!region) continue;
          const walker = document.createTreeWalker(region, NodeFilter.SHOW_TEXT);
          while (walker.nextNode()) {
            const node = walker.currentNode;
            if (!node.textContent?.trim() || node.parentElement?.closest('[aria-hidden="true"], .sr-only')) continue;
            const range = document.createRange();
            range.selectNodeContents(node);
            textRects.push(...Array.from(range.getClientRects()).map(r => clip(r, node.parentElement)).filter((r) => r.width && r.height));
          }
        }
        const candidates: { left: number; top: number }[] = [];
        for (let top = floor - box.height - 16; top >= ceiling; top -= 4) {
          candidates.push({ left: innerWidth - edge - box.width, top }, { left: edge, top });
        }
        if (!candidates.length) candidates.push({ left: edge, top: Math.max(0, floor - box.height - 16) });
        const area = (p: { left: number; top: number }, rects: DOMRect[]) => rects.reduce((sum, r) => sum + Math.max(0, Math.min(p.left + box.width + 4, r.right) - Math.max(p.left - 4, r.left)) * Math.max(0, Math.min(p.top + box.height + 4, r.bottom) - Math.max(p.top - 4, r.top)), 0);
        const overlap = (p: { left: number; top: number }) => area(p, controls) * 100 + area(p, textRects);
        let best = candidates[0], score = overlap(best);
        for (const candidate of candidates.slice(1)) {
          if (score === 0) break;
          const next = overlap(candidate);
          if (next < score) { best = candidate; score = next; }
        }
        // Si le texte agrandi remplit toute la hauteur, une place réelle est réservée
        // dans la barre de commandes. Aucun recouvrement n'est choisi par défaut.
        if (score > 0 && header) {
          reserveHeader = true;
          setPosition(headerPosition());
        } else setPosition((old) => old?.left === best.left && old?.top === best.top && !old?.headerSlot ? old : best);
      });
    }
    place();
    window.addEventListener('scroll', place, true);
    window.addEventListener('resize', place);
    visualViewport?.addEventListener('resize', place);
    visualViewport?.addEventListener('scroll', place);
    window.addEventListener('focusin', place);
    const observer = new MutationObserver(place);
    observer.observe(document.body, { childList: true, characterData: true, attributes: true, attributeFilter: ["class", "style", "open", "hidden"], subtree: true });
    // Les métriques de texte changent après le chargement des polices sans redimensionner main.
    document.fonts.addEventListener("loadingdone", place);
    let active = true;
    void document.fonts.ready.then(() => { if (active) place(); });
    const resize = new ResizeObserver(place);
    const main = document.querySelector('main');
    if (main) resize.observe(main);
    return () => { active = false; document.fonts.removeEventListener("loadingdone", place); cancelAnimationFrame(frame); observer.disconnect(); resize.disconnect(); window.removeEventListener('scroll', place, true); window.removeEventListener('resize', place); window.removeEventListener('focusin', place); visualViewport?.removeEventListener('resize', place); visualViewport?.removeEventListener('scroll', place); };
  }, [withNav]);
  return (
    <button ref={launcher} data-header-slot={position?.headerSlot || undefined} style={position ? { left: position.left, top: position.top, right: "auto", bottom: "auto" } : undefined} className={`chat-launcher ${withNav ? "" : "chat-launcher--nonav"}`} onClick={onOpen}
      aria-label={chatUnread ? t("chat.openUnread", { n: chatUnread }) : t("chat.open")}>
      <Icon name="chat" size={26} />
      {chatUnread > 0 && <span className="badge-count" aria-hidden="true">{chatUnread > 99 ? "99+" : chatUnread}</span>}
    </button>
  );
}

export function MessageList({ messages, myId, myName, partnerName }: { messages: ChatMessage[]; myId: string | null; myName: string; partnerName: string }) {
  const endRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    endRef.current?.scrollIntoView({ block: "end" });
  }, [messages.length]);
  return (
    <div role="log" aria-live="polite" className="stack stack--2">
      {messages.map((m) => {
        const mine = m.user_id === myId;
        return (
          <div key={m.client_id} className={`bubble ${mine ? "bubble--me" : ""}`}>
            <div>{m.body}</div>
            <div className="bubble__meta">
              <span className="sr-only">{mine ? myName : partnerName}, </span>
              <time dateTime={m.created_at}>{new Date(m.created_at).toLocaleString("fr-FR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })}</time>
              {m.pending && <> · {t("common.sending")}</>}
            </div>
          </div>
        );
      })}
      <div ref={endRef} />
    </div>
  );
}

/** Discussion du duo actif. Réduire conserve le brouillon (indexé par duo) et ne quitte pas la partie. */
export function ChatPanel({ onClose, inGame = false }: { onClose: () => void; inGame?: boolean }) {
  const { active, messages, sendMessage, markChatRead } = useDuo();
  const { userId, profile } = useAuth();
  const online = useOnline();
  const coupleId = active?.id ?? null;
  const [draft, setDraft] = useState("");
  const [error, setError] = useState<string | null>(null);
  const partnerName = active?.partner?.name || "?";

  // Brouillon propre à chaque duo : jamais envoyé à une autre personne.
  useEffect(() => {
    if (!coupleId) return;
    try {
      setDraft(sessionStorage.getItem(draftKey(coupleId)) ?? "");
    } catch {
      setDraft("");
    }
  }, [coupleId]);
  useEffect(() => {
    if (!coupleId) return;
    try {
      sessionStorage.setItem(draftKey(coupleId), draft);
    } catch {
      /* stockage indisponible */
    }
  }, [draft, coupleId]);
  useEffect(() => {
    if (coupleId) void markChatRead();
  }, [coupleId, messages.length, markChatRead]);

  async function submit(e?: FormEvent) {
    e?.preventDefault();
    const body = draft.trim();
    if (!body || !coupleId) return;
    setDraft("");
    const res = await sendMessage(body);
    setError(res.ok ? null : errorMessage(res.error));
  }

  if (!active) {
    return (
      <Sheet title={<h2 className="t-section">{t("chat.noDuoTitle")}</h2>} onClose={onClose}>
        <p>{t("chat.noDuoText")}</p>
        <Link className="btn" to="/inviter" onClick={onClose}>{t("duo.invite")}</Link>
      </Sheet>
    );
  }

  const failed = messages.filter((m) => m.failed);
  return (
    <Sheet
      tall
      side
      onClose={onClose}
      closeLabel={t("chat.minimize")}
      closeIcon="minus"
      title={
        <div className="row">
          <Avatar name={partnerName} path={active.partner?.avatar_path} size={40} />
          <div className="stack" style={{ gap: 0 }}>
            <h2 className="t-card">{partnerName}</h2>
            <span className="t-meta">{inGame ? t("chat.gameContinues") : t("chat.with", { name: partnerName })}</span>
          </div>
        </div>
      }
      footer={
        <>
          {(error || failed.length > 0) && (
            <div style={{ padding: "8px var(--gutter) 0" }}>
              <Alert>
                {error ?? t("chat.failed")}{" "}
                {failed.length > 0 && (
                  <button className="btn btn--quiet btn--auto btn--sm" onClick={() => failed.forEach((m) => void sendMessage(m.body, m.client_id))}>
                    {t("common.retry")}
                  </button>
                )}
              </Alert>
            </div>
          )}
          <form className="composer" onSubmit={submit}>
            <label htmlFor="chat-input" className="sr-only">{t("chat.placeholder", { name: partnerName })}</label>
            <textarea
              id="chat-input"
              className="input"
              rows={1}
              maxLength={1000}
              placeholder={t("chat.placeholder", { name: partnerName })}
              value={draft}
              data-autofocus
              onChange={(e) => {
                setDraft(e.target.value);
                e.target.style.height = "auto";
                e.target.style.height = `${Math.min(e.target.scrollHeight, 128)}px`;
              }}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void submit();
                }
              }}
            />
            <button className="icon-btn" type="submit" disabled={!online || !draft.trim()} aria-label={t("chat.send")}>
              <Icon name="send" />
            </button>
          </form>
        </>
      }
    >
      {messages.length === 0 ? <p className="muted center">{t("chat.empty")}</p> : (
        <MessageList messages={messages} myId={userId} myName={profile?.display_name ?? ""} partnerName={partnerName} />
      )}
    </Sheet>
  );
}
