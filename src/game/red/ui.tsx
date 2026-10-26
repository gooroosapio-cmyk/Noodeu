// Composants partagés du kit rouge : un seul cadre pour le salon et tous les jeux.
// Règles (05_integration/REGLES_UI_UX.txt) : en-tête 44–48, bandeau joueurs 52–60, avancement 24, illustration 120–176,
// cartes à hauteur automatique, actions dans le flux, jamais cachées par la conversation ou le clavier.
import type { CSSProperties, ReactNode, TextareaHTMLAttributes } from "react";
import { Link } from "react-router";
import { Avatar } from "../../components/Avatar";
import { Icon, type IconName } from "../../components/ui";
import type { Player } from "../../lib/types";
import { redBackground, redHero, type RedBackground, type RedKit } from "./kit";

/** Cadre d'écran : fond décoratif en haut de page, dégradé vers crème, contenu dans le flux. */
export function GameShell({ background, children, className = "" }: { background: RedBackground; children: ReactNode; className?: string }) {
  return <div className={`red-shell ${className}`} style={{ "--red-bg": `url("${redBackground(background)}")` } as CSSProperties}>{children}</div>;
}

/** En-tête court : réduire (chevron 44), titre unique, conversation et menu en cibles de 44. */
export function GameHeader({ title, reduceTo, onReduce, onChat, chatUnread = 0, onMenu, menuOpen = false }: {
  title: string; reduceTo: string; onReduce?: () => void; onChat?: () => void; chatUnread?: number; onMenu: () => void; menuOpen?: boolean;
}) {
  return (
    <header className="red-header">
      <Link className="red-icon-btn" to={reduceTo} aria-label="Réduire la partie et revenir à l’accueil" title="La partie continue ; retrouve-la sur l’accueil."
        onClick={(e) => { if (!e.metaKey && !e.ctrlKey && !e.shiftKey && !e.altKey && e.button === 0) onReduce?.(); }}>
        <Icon name="chevron-down" size={22} />
      </Link>
      <h1 className="red-header__title">{title}</h1>
      <div className="red-header__end">
        {onChat && <button type="button" className="red-icon-btn" onClick={onChat} aria-label={chatUnread ? `Conversation, ${chatUnread} non lus` : "Conversation"}>
          <Icon name="chat" size={22} />{chatUnread > 0 && <span className="red-badge" aria-hidden="true">{chatUnread > 9 ? "9+" : chatUnread}</span>}
        </button>}
        <button type="button" className="red-icon-btn" onClick={onMenu} aria-label="Règles et commandes de la partie" aria-haspopup="dialog" aria-expanded={menuOpen}>
          <Icon name="ellipsis" size={22} />
        </button>
      </div>
    </header>
  );
}

export type PresenceState = "here" | "waiting" | "away";
export interface DuoPerson { player?: Player; presence?: PresenceState; status?: string; score?: number | string; scoreLabel?: string; active?: boolean; ready?: boolean }

const presenceText: Record<PresenceState, string> = { here: "Connecté·e", waiting: "En attente", away: "Déconnecté·e" };

/** Bandeau des deux joueurs : une ligne, deux colonnes, avatars réels de 32. */
export function DuoStrip({ people, label = "Les joueurs" }: { people: DuoPerson[]; label?: string }) {
  return (
    <section className="red-duo" aria-label={label}>
      {people.map((d, i) => {
        const name = d.player ? d.player.display_name || (d.player.is_me ? "Toi" : "Partenaire") : "Deuxième joueur";
        const state = d.status ?? (d.presence ? presenceText[d.presence] : undefined);
        return (
          <div key={d.player?.seat ?? `vide-${i}`} className={`red-duo__who${d.active ? " is-active" : ""}${d.ready ? " is-ready" : ""}${d.player?.is_me ? " is-me" : ""}`}>
            {d.player ? <Avatar name={d.player.display_name} path={d.player.avatar_path} size={32} me={d.player.is_me} />
              : <span className="red-duo__empty" aria-hidden="true">?</span>}
            <span className="red-duo__text">
              <strong className="red-duo__name">{name}{d.player?.is_me && <span className="sr-only"> (toi)</span>}</strong>
              {state && <small className={`red-duo__state red-duo__state--${d.presence ?? "none"}`}>{state}</small>}
            </span>
            {d.score !== undefined && <span className="red-duo__score">{d.score}{d.scoreLabel && <small> {d.scoreLabel}</small>}</span>}
            {d.ready && <span className="red-duo__check"><Icon name="circle-check" size={20} label="Prêt" /></span>}
          </div>
        );
      })}
    </section>
  );
}

/** Manche i/N autoritaire : segments jusqu'à 10, au-delà une barre. */
export function RoundProgress({ current, total, label = "Manche", side }: { current: number; total: number; label?: string; side?: ReactNode }) {
  const n = Math.max(1, total);
  const i = Math.min(Math.max(current, 0), n);
  return (
    <div className="red-progress">
      <span className="red-progress__label">{label} {i}/{n}</span>
      {n <= 10 ? (
        <span className="red-progress__segments" role="progressbar" aria-valuemin={0} aria-valuemax={n} aria-valuenow={i} aria-label={`${label} ${i} sur ${n}`}>
          {Array.from({ length: n }, (_, k) => <span key={k} className={`red-progress__seg${k + 1 < i ? " is-done" : k + 1 === i ? " is-active" : ""}`} />)}
        </span>
      ) : (
        <span className="red-progress__track" role="progressbar" aria-valuemin={0} aria-valuemax={n} aria-valuenow={i} aria-label={`${label} ${i} sur ${n}`}>
          <span style={{ width: `${(100 * i) / n}%` }} />
        </span>
      )}
      {side && <span className="red-progress__side">{side}</span>}
    </div>
  );
}

/** Illustration principale : décorative, dimensions explicites, repli crème si elle manque. */
export function GameHero({ hero, size = "md", eager = false }: { hero: RedKit["hero"]; size?: "sm" | "md"; eager?: boolean }) {
  return (
    <div className={`red-hero red-hero--${size}`} aria-hidden="true">
      <img src={redHero(hero)} alt="" width={232} height={232} loading={eager ? "eager" : "lazy"} decoding="async"
        onError={(e) => { e.currentTarget.style.visibility = "hidden"; }} />
    </div>
  );
}

/** Carte de question : hauteur ajustée au texte, jamais tronquée. */
export function QuestionCard({ kicker, chips, children, tone = "plain" }: { kicker?: ReactNode; chips?: ReactNode; children: ReactNode; tone?: "plain" | "paper" }) {
  return (
    <article className={`red-card red-card--${tone}`}>
      {(kicker || chips) && <div className="red-card__head">{kicker && <span className="red-card__kicker">{kicker}</span>}{chips}</div>}
      {children}
    </article>
  );
}

/** Choix à poids égal : vrai bouton, état sélectionné avec coche, bordure et libellé. */
export function ChoiceCard({ label, hint, image, selected, disabled, onSelect, role = "radio", tone = "neutral", layout = "column" }: {
  label: ReactNode; hint?: ReactNode; image?: string; selected?: boolean; disabled?: boolean; onSelect: () => void;
  role?: "radio" | "button"; tone?: "neutral" | "red" | "cream"; layout?: "column" | "row";
}) {
  return (
    <button type="button" className={`red-choice red-choice--${tone}${layout === "row" ? " red-choice--row" : ""}`} role={role} aria-checked={role === "radio" ? Boolean(selected) : undefined}
      aria-pressed={role === "button" ? Boolean(selected) : undefined} disabled={disabled} onClick={onSelect}>
      {image && <img className="red-choice__img" src={image} alt="" width={112} height={112} loading="lazy" decoding="async" />}
      <span className="red-choice__label">{label}</span>
      {hint && <span className="red-choice__hint">{hint}</span>}
      {role === "radio" && <span className="red-choice__mark" aria-hidden="true">{selected && <Icon name="check" size={14} />}</span>}
    </button>
  );
}

/** Zone de saisie 96–144, auto-extensible jusqu'à 240 ; police 16 pour éviter le zoom automatique. */
export function GameTextarea({ id, label, value, max, onChange, hint, ...rest }: Omit<TextareaHTMLAttributes<HTMLTextAreaElement>, "onChange" | "value"> & {
  id: string; label: ReactNode; value: string; max: number; onChange: (v: string) => void; hint?: ReactNode;
}) {
  return (
    <div className="red-field">
      <label className="red-field__label" htmlFor={id}>{label}</label>
      <textarea {...rest} id={id} className="red-input red-textarea" maxLength={max} value={value} aria-describedby={`${id}-count`}
        onChange={(e) => { onChange(e.target.value); const el = e.currentTarget; el.style.height = "auto"; el.style.height = `${Math.min(240, el.scrollHeight)}px`; }}
        onFocus={(e) => e.currentTarget.scrollIntoView({ block: "center", behavior: "smooth" })} />
      <span id={`${id}-count`} className="red-field__count">{hint ? <>{hint} · </> : null}{max - value.length} caractères restants</span>
    </div>
  );
}

/** Actions collantes dans le flux, au-dessus de la zone sûre ; espace réservé, jamais sous une bulle. */
export function GameActions({ children, note }: { children: ReactNode; note?: ReactNode }) {
  return <div className="red-actions">{children}{note && <p className="red-actions__note">{note}</p>}</div>;
}

/** Statut compact, annoncé poliment. */
export function ReadyStatus({ icon = "clock", children, tone = "wait" }: { icon?: IconName; children: ReactNode; tone?: "wait" | "ok" | "info" }) {
  return <p className={`red-status red-status--${tone}`} role="status" aria-live="polite"><Icon name={icon} size={18} />{children}</p>;
}

/** Ligne de réglage : libellé + aide à gauche, contrôle à droite. */
export function GameSettingsRow({ icon, label, help, children, htmlFor }: { icon: IconName; label: string; help?: string; children: ReactNode; htmlFor?: string }) {
  return (
    <div className="red-setting">
      <span className="red-setting__icon" aria-hidden="true"><Icon name={icon} size={20} /></span>
      <span className="red-setting__text">
        {htmlFor ? <label htmlFor={htmlFor}><strong>{label}</strong></label> : <strong>{label}</strong>}
        {help && <small>{help}</small>}
      </span>
      <span className="red-setting__control">{children}</span>
    </div>
  );
}

/** Panneau de résultat : victoire, égalité ou « on réessaie », sans jugement. */
export function ResultPanel({ kind, title, text, children }: { kind: "victoire" | "egalite" | "defaite" | "fin"; title: string; text?: ReactNode; children?: ReactNode }) {
  const hero = kind === "egalite" ? "trophees_egalite" : kind === "defaite" ? "coeur_reessayer" : "trophee_victoire";
  return (
    <section className={`red-result red-result--${kind}`} aria-live="polite">
      <GameHero hero={hero} size="sm" eager />
      <h2 className="red-result__title">{title}</h2>
      {text && <p className="red-result__text">{text}</p>}
      {children}
    </section>
  );
}

/** Bandeau de reconnexion compact, à la place d'un écran vide. */
export function ReconnectBanner({ online, onRetry, networkError }: { online: boolean; networkError: boolean; onRetry: () => void }) {
  if (online && !networkError) return null;
  return (
    <div className="red-reconnect" role="status">
      <img src={redHero("pause_reconnexion")} alt="" width={40} height={40} aria-hidden="true" />
      <p className="grow"><strong>{online ? "Connexion interrompue" : "En attente du réseau"}</strong><br />
        <small>{online ? "La dernière version reste affichée." : "La partie reste affichée ; rien n’est perdu."}</small></p>
      {online && <button type="button" className="red-btn red-btn--secondary red-btn--auto" onClick={onRetry}>Réessayer</button>}
    </div>
  );
}
