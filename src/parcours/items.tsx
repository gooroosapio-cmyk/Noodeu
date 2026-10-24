import { useCallback, useEffect, useState } from "react";
import { t, type MessageKey } from "../i18n";
import { supabase } from "../lib/supabase";
import { useAuth } from "../auth/AuthProvider";
import { Icon, useToast } from "../components/ui";
import type { Intensity } from "../lib/types";

/** Vue d'une question renvoyée par le serveur (texte masqué si elle demande un +18 qui n'est plus activé). */
export interface ItemView {
  hidden?: boolean; text?: string; prompt?: string; options?: { text: string }[]; kind?: string; adult?: boolean; theme?: string;
  intensity?: Intensity; duration_kind?: "rapide" | "discussion"; minutes_min?: number; minutes_max?: number; long_followup?: string;
}
export type Feedback = "utile" | "trop_intime" | "bien_adaptee";
export const FEEDBACKS: Feedback[] = ["utile", "trop_intime", "bien_adaptee"];

export function itemText(v: ItemView | null | undefined) {
  if (!v || v.hidden) return "";
  if (v.prompt) return `${v.prompt}${v.options?.length ? ` ${v.options.map((o) => o.text).join(" / ")}` : ""}`;
  return v.text ?? "";
}

export function ItemChips({ v }: { v: ItemView }) {
  return (
    <div className="row row--wrap" style={{ gap: 6 }}>
      {v.theme && <span className="nd-chip nd-chip--peach">{v.theme}</span>}
      {v.intensity && <span className="nd-chip">{t(`filter.intensity.${v.intensity}`)}</span>}
      {v.duration_kind && (
        <span className="nd-chip nd-chip--mint">
          {v.duration_kind === "rapide" ? t("daily.quick") : t("daily.discussion", { min: v.minutes_min ?? 5, max: v.minutes_max ?? 10 })}
        </span>
      )}
      {v.adult && <span className="nd-chip">{t("daily.adult")}</span>}
    </div>
  );
}

/** Favori, Plus tard et retour privé sur une question : données personnelles, jamais transmises à l'autre. */
export function useItemState(bank: string | null, itemId: string | null) {
  const { userId } = useAuth();
  const [fav, setFav] = useState(false);
  const [later, setLater] = useState(false);
  const [feedback, setFeedback] = useState<Feedback | null>(null);
  useEffect(() => {
    if (!userId || !bank || !itemId) return;
    let alive = true;
    void Promise.all([
      supabase.from("item_favorites").select("item_id").eq("bank", bank).eq("item_id", itemId).maybeSingle(),
      supabase.from("later_items").select("item_id").eq("bank", bank).eq("item_id", itemId).maybeSingle(),
      supabase.from("item_feedback").select("value").eq("bank", bank).eq("item_id", itemId).maybeSingle(),
    ]).then(([f, l, b]) => {
      if (!alive) return;
      setFav(Boolean(f.data));
      setLater(Boolean(l.data));
      setFeedback(((b.data as { value?: Feedback } | null)?.value) ?? null);
    });
    return () => { alive = false; };
  }, [userId, bank, itemId]);

  const toggleFav = useCallback(async () => {
    if (!userId || !bank || !itemId) return false;
    const { error } = fav
      ? await supabase.from("item_favorites").delete().eq("user_id", userId).eq("bank", bank).eq("item_id", itemId)
      : await supabase.from("item_favorites").upsert({ user_id: userId, kind: "question", bank, item_id: itemId }, { onConflict: "user_id,bank,item_id", ignoreDuplicates: true });
    if (!error) setFav(!fav);
    return !error;
  }, [userId, bank, itemId, fav]);

  const toggleLater = useCallback(async () => {
    if (!userId || !bank || !itemId) return false;
    const { error } = later
      ? await supabase.from("later_items").delete().eq("user_id", userId).eq("bank", bank).eq("item_id", itemId)
      : await supabase.from("later_items").upsert({ user_id: userId, bank, item_id: itemId }, { onConflict: "user_id,bank,item_id", ignoreDuplicates: true });
    if (!error) setLater(!later);
    return !error;
  }, [userId, bank, itemId, later]);

  const give = useCallback(async (value: Feedback) => {
    if (!userId || !bank || !itemId) return false;
    const { error } = feedback === value
      ? await supabase.from("item_feedback").delete().eq("user_id", userId).eq("bank", bank).eq("item_id", itemId)
      : await supabase.from("item_feedback").upsert({ user_id: userId, bank, item_id: itemId, value, updated_at: new Date().toISOString() }, { onConflict: "user_id,bank,item_id" });
    if (!error) setFeedback(feedback === value ? null : value);
    return !error;
  }, [userId, bank, itemId, feedback]);

  return { fav, later, feedback, toggleFav, toggleLater, give };
}

export function ItemActions({ bank, itemId }: { bank: string; itemId: string }) {
  const s = useItemState(bank, itemId);
  const toast = useToast();
  const done = (ok: boolean) => toast(ok ? t("common.saved") : t("profile.error"));
  return (
    <div className="stack stack--2">
      <div className="row row--wrap" style={{ gap: "var(--s-2)" }}>
        <button type="button" className="btn btn--secondary btn--sm btn--auto" aria-pressed={s.fav} onClick={async () => done(await s.toggleFav())}>
          <Icon name={s.fav ? "star" : "bookmark"} size={18} />{s.fav ? t("items.favOn") : t("items.fav")}
        </button>
        <button type="button" className="btn btn--secondary btn--sm btn--auto" aria-pressed={s.later} onClick={async () => done(await s.toggleLater())}>
          <Icon name={s.later ? "bookmark-filled" : "clock"} size={18} />{s.later ? t("rhythm.laterDone") : t("rhythm.later")}
        </button>
      </div>
      <fieldset className="filter-group">
        <legend className="t-meta">{t("items.feedback")}</legend>
        <div className="chips">
          {FEEDBACKS.map((f) => (
            <button key={f} type="button" className="chip" aria-pressed={s.feedback === f} onClick={async () => done(await s.give(f))}>
              {t(`items.feedback.${f}` as MessageKey)}
            </button>
          ))}
        </div>
      </fieldset>
    </div>
  );
}
