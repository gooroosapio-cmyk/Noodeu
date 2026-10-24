import { useEffect, useState } from "react";
import { t } from "../i18n";
import { rpc } from "../lib/supabase";
import { Icon } from "../components/ui";
import type { Intensity } from "../lib/types";
import { intensityRank } from "../screens/catalog";

interface Meta { intensity?: Intensity; duration_kind?: string; long_followup?: string }

/** Métadonnées des cartes déjà tirées dans la partie (intensité, version approfondie), rechargées à chaque manche. */
export function useSessionMeta(sessionId: string, round: number) {
  const [items, setItems] = useState<Record<string, Meta>>({});
  useEffect(() => {
    let alive = true;
    void rpc<{ items: Record<string, Meta> }>("get_session_meta", { p_session: sessionId }).then((r) => {
      if (alive && r.ok) setItems((r as unknown as { items: Record<string, Meta> }).items ?? {});
    });
    return () => { alive = false; };
  }, [sessionId, round]);
  return items;
}

/** Phrase de transition quand l'intensité monte d'une carte à la suivante. */
export function IntensityTransition({ prev, cur }: { prev?: Meta; cur?: Meta }) {
  if (!prev?.intensity || !cur?.intensity || intensityRank(cur.intensity) <= intensityRank(prev.intensity)) return null;
  return <p className="t-small transition-note"><Icon name="leaf" size={16} />{t(cur.intensity === "hot" ? "transition.hot" : "transition.moyen")}</p>;
}

/** Version courte (la question telle quelle) ou approfondie (une relance en plus, jamais une réécriture). */
export function DeepToggle({ followup, roundKey }: { followup?: string; roundKey: number }) {
  const [deep, setDeep] = useState(false);
  useEffect(() => setDeep(false), [roundKey]);
  if (!followup) return null;
  return (
    <div className="stack stack--2">
      <div className="chips" role="radiogroup" aria-label={t("daily.version")}>
        <button type="button" className="chip" role="radio" aria-checked={!deep} onClick={() => setDeep(false)}>{t("daily.short")}</button>
        <button type="button" className="chip" role="radio" aria-checked={deep} onClick={() => setDeep(true)}>{t("daily.deep")}</button>
      </div>
      {deep && <p className="t-small"><Icon name="sparkles" size={16} /> {followup}</p>}
    </div>
  );
}
