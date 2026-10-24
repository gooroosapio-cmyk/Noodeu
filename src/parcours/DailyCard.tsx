import { useCallback, useEffect, useState } from "react";
import { t } from "../i18n";
import { rpc, supabase } from "../lib/supabase";
import { useOnline } from "../lib/useOnline";
import { Alert, Icon, Loading } from "../components/ui";
import { ItemActions, ItemChips, itemText, type ItemView } from "./items";

type Mode = "hasard" | "theme" | "saison";
interface Daily { day: string; mode: Mode; theme: string | null; redraws_left: number; bank: string; item_id: string; shared: boolean; card: ItemView | null }

function deviceTz() {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || null;
  } catch {
    return null;
  }
}

/** Question du jour : la même pour les deux membres du duo, gardée toute la journée (fuseau du duo). */
export function DailyCard() {
  const online = useOnline();
  const [daily, setDaily] = useState<Daily | null>(null);
  const [themes, setThemes] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [deep, setDeep] = useState(false);
  const [choose, setChoose] = useState(false);

  const load = useCallback(async (mode?: Mode, theme?: string) => {
    setBusy(true);
    setError(null);
    const res = await rpc<Daily>("get_daily", { p_mode: mode ?? null, p_theme: theme ?? null, p_tz: deviceTz() });
    setBusy(false);
    if (res.ok) {
      setDaily(res as unknown as Daily);
      setDeep(false);
      setChoose(false);
    } else setError(res.error === "no_card_for_filter" ? t("daily.noneForFilter") : res.error === "no_card" ? t("daily.none") : t("daily.error"));
  }, []);

  useEffect(() => {
    void load();
    void supabase.rpc("get_daily_themes").then(({ data }) => {
      if (Array.isArray(data)) setThemes(data as string[]);
    });
  }, [load]);

  return (
    <section className="section" aria-labelledby="home-daily">
      <div className="section__head">
        <h2 className="t-section" id="home-daily">{t("daily.title")}</h2>
        {daily && daily.redraws_left > 0 && (
          <button className="btn btn--quiet btn--auto btn--sm" aria-expanded={choose} onClick={() => setChoose((v) => !v)}>{t("daily.change")}</button>
        )}
      </div>
      {choose && daily && (
        <div className="filter-panel stack">
          <div className="chips" role="group" aria-label={t("daily.change")}>
            <button className="chip" disabled={busy || !online} onClick={() => void load("hasard")}><Icon name="dices" size={16} />{t("daily.mode.hasard")}</button>
            <button className="chip" disabled={busy || !online} onClick={() => void load("saison")}><Icon name="leaf" size={16} />{t("daily.mode.saison")}</button>
          </div>
          {themes.length > 0 && (
            <label className="field">
              <span className="field__label">{t("daily.mode.theme")}</span>
              <select className="input" defaultValue="" disabled={busy || !online} onChange={(e) => e.target.value && void load("theme", e.target.value)}>
                <option value="">{t("daily.pickTheme")}</option>
                {themes.map((th) => <option key={th} value={th}>{th}</option>)}
              </select>
            </label>
          )}
          <p className="t-meta">{t(daily.shared ? "daily.changeShared" : "daily.changeSolo", { n: daily.redraws_left })}</p>
        </div>
      )}
      {error && <Alert kind="info">{error}</Alert>}
      {!daily ? (!error && <Loading />) : !daily.card || daily.card.hidden ? (
        <div className="card"><p className="muted">{t("daily.hidden")}</p></div>
      ) : (
        <article className="card daily-card stack stack--4">
          <ItemChips v={daily.card} />
          <p className="t-question">{itemText(daily.card)}</p>
          {daily.card.long_followup && (
            <div className="stack stack--2">
              <div className="chips" role="radiogroup" aria-label={t("daily.version")}>
                <button className="chip" role="radio" aria-checked={!deep} onClick={() => setDeep(false)}>{t("daily.short")}</button>
                <button className="chip" role="radio" aria-checked={deep} onClick={() => setDeep(true)}>{t("daily.deep")}</button>
              </div>
              {deep && <p className="t-small"><Icon name="sparkles" size={16} /> {daily.card.long_followup}</p>}
            </div>
          )}
          <p className="t-meta row"><Icon name={daily.shared ? "users" : "user"} size={16} />{daily.shared ? t("daily.sharedHint") : t("daily.soloHint")}</p>
          <ItemActions bank={daily.bank} itemId={daily.item_id} />
        </article>
      )}
    </section>
  );
}
