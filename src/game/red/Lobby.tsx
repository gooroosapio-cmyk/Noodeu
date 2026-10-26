// Salon de séance (kit rouge) : préparer → validation des deux → tout est prêt → lancement par l'hôte.
// Présence réseau et accord sur les réglages sont deux états distincts. Une validation n'est valable que pour la
// révision de réglages acceptée ; tout changement les remet à zéro côté serveur. Pas de démarrage silencieux.
import { useState } from "react";
import { t } from "../../i18n";
import { Icon, Sheet } from "../../components/ui";
import type { Player, SessionState } from "../../lib/types";
import { NudgeButton } from "../premium/Nudge";
import type { RedKit } from "./kit";
import { DuoStrip, GameActions, GameHero, GameSettingsRow, ReadyStatus, type PresenceState } from "./ui";

type Run = (fn: string, args?: Record<string, unknown>) => Promise<{ ok: boolean; error?: string }>;
type SettingDef = { label: string; options: (string | number)[]; default: string | number };

interface Cfg { mechanic?: string; turn?: string; rounds_setting?: string; settings?: Record<string, SettingDef>;
  parameters?: { target?: number; wins_target?: number; choice_timeout_seconds?: number; boxes?: number; rows?: number; columns?: number; fleet?: number[]; shots_per_turn?: number };
  test?: { count?: number }; pack?: { set_size?: number } }

/** Faits utiles d'un jeu sans réglage, tirés de la configuration réelle. */
function facts(st: SessionState): string[] {
  const cfg = st.game.config as unknown as Cfg;
  const p = cfg.parameters ?? {};
  if (cfg.mechanic === "nd_pig") return [`Objectif ${p.target ?? 30} points`, "Un 1 annule le tour"];
  if (p.wins_target) return [`${p.wins_target} victoires pour gagner`, `${p.choice_timeout_seconds ?? 30} s pour choisir`];
  if (cfg.mechanic === "battleship") return [`${p.rows ?? 10} × ${p.columns ?? 10} cases`, `${p.fleet?.length ?? 5} navires (${(p.fleet ?? [5, 4, 3, 3, 2]).join("/")})`, `${p.shots_per_turn ?? 1} tir par tour`];
  if (cfg.mechanic === "dots_boxes") return [`${p.boxes ?? 16} carrés`, "Un carré fermé te fait rejouer"];
  if (cfg.mechanic === "nd_name_three_call") return ["10 s par consigne", "Réussi +3 · Raté 0", "Objectif 30", "En appel"];
  if (cfg.mechanic === "nd_categories_stop") return ["8 rubriques", "Une lettre par manche"];
  if (cfg.mechanic === "test_form" && cfg.test?.count) return [`${cfg.test.count} questions`, "Ordre préservé"];
  if (cfg.mechanic === "pack_conversation") return [cfg.pack?.set_size ? `Séries de ${cfg.pack.set_size} questions` : "Carte après carte"];
  return [];
}

export function modeLabel(st: SessionState) {
  const cfg = st.game.config as unknown as Cfg;
  if (cfg.mechanic === "test_form") return "Se découvrir";
  if (cfg.mechanic === "pack_conversation") return "Questions à deux";
  return cfg.turn === "simultaneous" ? "À vous deux" : "À tour de rôle";
}

export function RedLobby({ st, kit, me, partner, partnerHere, busy, online, run, onRules, onOptions }: {
  st: SessionState; kit: RedKit; me?: Player; partner?: Player; partnerHere: boolean; busy: boolean; online: boolean; run: Run;
  onRules: () => void; onOptions?: () => void;
}) {
  const [about, setAbout] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const cfg = st.game.config as unknown as Cfg;
  // Les réglages universels passent par la fenêtre d'options quand le jeu a aussi des préférences privées.
  const settings = onOptions ? {} : cfg.settings ?? {};
  const rev = st.session.settings_rev;
  const revAware = typeof rev === "number";
  const agreed = (p?: Player) => Boolean(p?.ready && (!revAware || p.ready_rev === rev));
  const mine = agreed(me), theirs = agreed(partner), both = mine && theirs;
  const host = (st.session.host_seat ?? 1) === me?.seat;
  const locked = busy || !online || Boolean(st.session.read_only) || !me;
  const partnerName = partner?.display_name || "l’autre joueur";
  const roundsKey = cfg.rounds_setting;
  const rounds = roundsKey ? st.session.settings[roundsKey] ?? settings[roundsKey]?.default : st.session.total_rounds;
  const sexual = st.game.content_level === "intime" || Boolean(st.game.adult_available);
  const presence = (p?: Player): PresenceState => (!p?.user_id ? "waiting" : p.is_me ? (online ? "here" : "away") : partnerHere ? "here" : "away");
  const list = facts(st);

  async function validate(ready: boolean) {
    setNotice(null);
    const res = revAware ? await run("set_ready_rev", { p_ready: ready, p_rev: rev }) : await run("set_ready", { p_ready: ready });
    if (!res.ok && res.error === "settings_changed") setNotice("Les réglages viennent de changer : vérifie-les puis valide à nouveau.");
  }
  async function launch() {
    setNotice(null);
    const res = await run("launch_session", { p_rev: rev });
    if (!res.ok && res.error === "settings_changed") setNotice("Les réglages viennent de changer : validez-les à nouveau tous les deux.");
  }

  const ready = both && revAware;
  return (
    <section className="red-lobby red-enter" aria-labelledby="red-lobby-title">
      <GameHero hero={kit.hero} size="sm" eager />
      <div className="red-lobby__game">
        <h2 className="red-lobby__title" id="red-lobby-title">{ready ? "Tout est prêt" : st.game.title}</h2>
        <p className="red-lobby__mode">{ready && <>{st.game.title} · </>}{roundsKey && rounds ? `${rounds} ${settings[roundsKey]?.label?.toLowerCase().includes("tour") ? "tours" : "manches"} · ` : ""}{modeLabel(st)}</p>
        {!ready && st.game.rules.objective && <p className="red-lobby__objective">{st.game.rules.objective}</p>}
        <div className="red-lobby__links">
          <button type="button" className="red-link-btn" onClick={onRules}><Icon name="book-open" size={18} />Règles</button>
          <button type="button" className="red-link-btn" onClick={() => setAbout(true)}><Icon name="info" size={18} />En savoir plus</button>
        </div>
      </div>

      <DuoStrip label="Joueurs du salon" people={[me, partner].map((p) => ({
        player: p, presence: presence(p), ready: agreed(p),
        status: !p ? "En attente" : agreed(p) ? (p.is_me ? "Validé" : "Prêt·e") : undefined,
      }))} />

      {!ready && (Object.keys(settings).length > 0 || onOptions || list.length > 0) && (
        <div className="red-settings" aria-label="Réglages de la partie">
          {Object.entries(settings).map(([key, def]) => {
            const value = String(st.session.settings[key] ?? def.default);
            const change = (opt: string | number) => void run("update_session_settings", { p_settings: { [key]: opt } });
            return (
              <GameSettingsRow key={key} icon={key === roundsKey ? "cards" : "settings"} label={def.label}
                help={mine ? "Retire ta validation pour modifier" : undefined} htmlFor={def.options.length > 4 ? `red-set-${key}` : undefined}>
                {def.options.length <= 4 ? (
                  <span className="red-seg" role="radiogroup" aria-label={def.label}>
                    {def.options.map((opt) => (
                      <label key={String(opt)}>
                        <input className="sr-only" type="radio" name={`red-${key}`} checked={value === String(opt)} disabled={locked || mine}
                          onChange={() => change(opt)} />
                        <span>{String(opt)}</span>
                      </label>
                    ))}
                  </span>
                ) : (
                  <select id={`red-set-${key}`} className="red-select" value={value} disabled={locked || mine}
                    onChange={(e) => { const opt = def.options.find((o) => String(o) === e.target.value); if (opt !== undefined) change(opt); }}>
                    {def.options.map((opt) => <option key={String(opt)} value={String(opt)}>{String(opt)}</option>)}
                  </select>
                )}
              </GameSettingsRow>
            );
          })}
          {onOptions && (
            <GameSettingsRow icon="settings" label={t("rounds.options")} help="Manches, thèmes et préférences">
              <button type="button" className="red-btn red-btn--secondary red-btn--auto" aria-label="Modifier les options" disabled={locked || mine} onClick={onOptions}>Modifier</button>
            </GameSettingsRow>
          )}
          {list.length > 0 && Object.keys(settings).length === 0 && !onOptions && (
            <ul className="red-facts" aria-label="Règles de cette activité" style={{ padding: "8px 0" }}>{list.map((f) => <li key={f}>{f}</li>)}</ul>
          )}
        </div>
      )}
      {sexual && <ReadyStatus icon="shield-check" tone="info">+18 · Tu peux passer à tout moment.</ReadyStatus>}

      {notice && <ReadyStatus icon="info" tone="info">{notice}</ReadyStatus>}
      {!revAware ? null : ready ? (
        host
          ? <ReadyStatus icon="circle-check" tone="ok">{partnerHere ? "Vous avez validé les mêmes réglages." : `${partnerName} doit être dans le salon pour lancer.`}</ReadyStatus>
          : <ReadyStatus icon="circle-check" tone="ok">{`Tout est prêt : ${partnerName} lance la partie.`}</ReadyStatus>
      ) : mine ? (
        <ReadyStatus>{partner?.user_id ? partnerHere ? `En attente de la validation de ${partnerName}` : `${partnerName} n’est pas encore dans le salon` : "En attente du deuxième joueur"}</ReadyStatus>
      ) : theirs ? (
        <ReadyStatus icon="check" tone="info">{`${partnerName} a validé ces réglages.`}</ReadyStatus>
      ) : null}

      <GameActions note={!ready ? "Un changement de réglage demande aux deux de valider à nouveau." : undefined}>
        {ready ? (
          <>
            {host && <button type="button" className="red-btn" disabled={locked || !partnerHere} onClick={() => void launch()}>
              <Icon name="play" size={20} />{busy ? t("common.sending") : "Lancer la partie"}</button>}
            <button type="button" className="red-btn red-btn--secondary" disabled={locked} onClick={() => void validate(false)}>Modifier les réglages</button>
          </>
        ) : mine ? (
          <>
            {partner && <NudgeButton st={st} partner={partner} />}
            <button type="button" className="red-btn red-btn--secondary" disabled={locked} onClick={() => void validate(false)}>Modifier les réglages</button>
          </>
        ) : (
          <button type="button" className="red-btn" disabled={locked} onClick={() => void validate(true)}>
            <Icon name="check" size={20} />{busy ? t("common.sending") : "Valider les réglages"}
          </button>
        )}
      </GameActions>

      {about && (
        <Sheet title={<h2 className="t-section">{st.game.title}</h2>} onClose={() => setAbout(false)}>
          <p>{st.game.rules.objective || st.game.title}</p>
          {list.length > 0 && <ul className="red-facts" style={{ justifyContent: "flex-start" }}>{list.map((f) => <li key={f}>{f}</li>)}</ul>}
          {st.game.rules.privacy && <p className="t-small">{st.game.rules.privacy}</p>}
        </Sheet>
      )}
    </section>
  );
}
