/* eslint-disable @typescript-eslint/no-explicit-any */
// Scènes premium des jeux de conversation (G01–G05, G09, G10) : choix à poids égal, révélations par univers.
// Aucune réponse de l'autre n'est affichée avant que le serveur ne l'ait révélée (card.answers).
import { t } from "../../i18n";
import { Icon } from "../../components/ui";
import { Avatar } from "../../components/Avatar";
import type { Player, SessionState } from "../../lib/types";
import { NudgeButton } from "./Nudge";

type J = any;
const nameOf = (p?: Player) => (p ? (p.is_me ? t("game.you") : p.display_name || "?") : "?");
const Q = "/assets/premium/questions";

/** Mécaniques à choix dont la révélation regroupe les deux réponses par option. */
export const CHOICE_SCENES = new Set(["nd_never", "nd_dilemma", "nd_opinion", "nd_duo_target"]);

/** G01 : deux sceaux tactiles, Vérité et Action. */
export function TruthDareSeals({ busy, onPick }: { busy: boolean; onPick: (kind: "truth" | "dare") => void }) {
  return (
    <div className="stack stack--3">
      <p className="t-small">{t("conv.td.choose")}</p>
      <div className="seals">
        {(["truth", "dare"] as const).map((k) => (
          <button key={k} type="button" className={`seal seal--${k}`} disabled={busy} onClick={() => onPick(k)}>
            <img src={`${Q}/${k}.svg`} alt="" width={72} height={72} />
            <span>{t(k === "truth" ? "conv.td.truth" : "conv.td.dare")}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

/** Attente du tour de l'autre, avec relance. */
export function WaitTurn({ st, partner, text }: { st: SessionState; partner?: Player; text: string }) {
  return (
    <div className="wait-turn stack stack--3">
      <p className="t-small row wait-turn__line"><img src="/assets/premium/shared/waiting.svg" alt="" width={24} height={24} />{text}</p>
      <NudgeButton st={st} partner={partner} />
    </div>
  );
}

/** Classe d'habillage des choix scellés selon le jeu (même poids visuel pour chaque option). */
export const pickClass = (mech: string) =>
  mech === "nd_never" ? "pick pick--stamps" : mech === "nd_dilemma" ? "pick pick--doors" : mech === "nd_opinion" ? "pick pick--bubbles" : "pick";

/** Révélation groupée : chaque option avec les personnes qui l'ont choisie, sans verdict ni « bonne » réponse. */
export function ChoiceReveal({ card, players }: { card: J; players: Player[] }) {
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const people = [me, partner].filter(Boolean) as Player[];
  const target = card.mech === "nd_duo_target";
  const options: { id: string; text: string; player?: Player }[] = target
    ? people.map((p) => ({ id: String(p.seat), text: p.is_me ? `${p.display_name} (${t("game.you")})` : p.display_name || "?", player: p }))
    : (card.options ?? []);
  const chose = (p: Player, id: string) => {
    const a = card.answers?.[p.seat];
    return target ? String(a?.seat) === id : a?.choice === id;
  };
  const same = people.length === 2 && options.some((o) => people.every((p) => chose(p, o.id)));
  return (
    <div className={`stack stack--3 enter reveal reveal--${card.mech}`} aria-live="polite">
      <div className="reveal__grid">
        {options.map((o) => {
          const who = people.filter((p) => chose(p, o.id));
          return (
            <section key={o.id} className={`reveal__tile${who.length ? " is-chosen" : ""}`} aria-label={`${o.text} : ${who.map(nameOf).join(", ") || t("conv.reveal.nobody")}`}>
              {o.player && <Avatar name={o.player.display_name} path={o.player.avatar_path} size={48} me={o.player.is_me} />}
              <p className="reveal__text">{o.text}</p>
              <ul className="reveal__who">
                {who.map((p) => (
                  <li key={p.seat} className={`reveal__stamp${p.is_me ? " is-me" : ""}`}>
                    {target ? t("conv.reveal.votedBy", { name: nameOf(p) }) : nameOf(p)}
                  </li>
                ))}
              </ul>
            </section>
          );
        })}
      </div>
      <p className="t-meta center">{same ? t("conv.reveal.same") : t("conv.reveal.different")}</p>
    </div>
  );
}

/** Révélation en texte : rubans (Complète la phrase) ou enveloppes en vis-à-vis (Devine ma réponse). */
export function TextReveal({ card, players, label }: { card: J; players: Player[]; label: (p: Player) => string }) {
  const me = players.find((p) => p.is_me)!;
  const partner = players.find((p) => !p.is_me);
  const kind = card.mech === "nd_predict" ? "envelope" : "ribbon";
  return (
    <div className={`stack stack--3 enter reveal reveal--${kind}`} aria-live="polite">
      {[me, partner].filter(Boolean).map((p) => (
        <section key={p!.seat} className={`reveal__${kind}${p!.is_me ? " is-me" : ""}`}>
          <header className="row">
            <Avatar name={p!.display_name} path={p!.avatar_path} size={32} me={p!.is_me} />
            <h3 className="t-meta strong">{label(p!)}</h3>
          </header>
          <p className="q-answer__text">{card.answers?.[p!.seat]?.text ?? ""}</p>
        </section>
      ))}
    </div>
  );
}

/** Carte d'Action ou Vérité révélée, avec son état « fait » ou « passé ». */
export function TruthDareDone({ card, player }: { card: J; player?: Player }) {
  return (
    <section className={`td-done td-done--${card.kind ?? "truth"}`}>
      <img src={`${Q}/${card.kind === "dare" ? "dare" : "truth"}.svg`} alt="" width={40} height={40} />
      <div className="stack stack--1 grow">
        <h3 className="t-meta strong">{nameOf(player)}</h3>
        <p className="q-answer__text">{card.response?.text ?? t("conv.td.actionDone")}</p>
      </div>
      <span className="td-done__state"><Icon name="check" size={14} />{card.kind === "dare" ? t("conv.td.stateDone") : t("conv.td.stateAnswered")}</span>
    </section>
  );
}
