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

