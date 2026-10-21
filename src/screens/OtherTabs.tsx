import { useEffect, useState, type FormEvent } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { supabase, rpc } from "../lib/supabase";
import { errorMessage } from "../lib/errors";
import { useAuth } from "../auth/AuthProvider";
import { WordFormField } from "../auth/AuthScreens";
import { useCouple } from "../couple/CoupleProvider";
import { Alert, Avatar, EmptyState, Icon, Loading, PageLoading, formatDate } from "../components/ui";
import type { WordForm } from "../lib/types";

/** Astuces : rubrique personnelle. Les 500 cartes attendent leur validation éditoriale (décision 11B). */
export function Tips() {
  return (
    <main className="page">
      <div className="page-head">
        <h1>{t("tips.title")}</h1>
        <p>{t("tips.subtitle")}</p>
      </div>
      <EmptyState illustration="12-astuce" title={t("tips.soonTitle")} text={t("tips.soonText")} />
    </main>
  );
}

interface HistoryItem {
  id: string;
  status: string;
  created_at: string;
  ended_at: string | null;
  couple_id: string;
  games: { title: string } | null;
  session_players: { keep_memory: boolean }[];
}

export function OurSpace() {
  const couple = useCouple();
  const { profile } = useAuth();
  const [history, setHistory] = useState<HistoryItem[] | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    void supabase
      .from("game_sessions")
      .select("id, status, created_at, ended_at, couple_id, games(title), session_players(keep_memory)")
      .in("status", ["ended", "closed"])
      .order("created_at", { ascending: false })
      .limit(20)
      .then(({ data, error: e }) => {
        setError(Boolean(e));
        setHistory((data as unknown as HistoryItem[]) ?? []);
      });
  }, [couple.coupleId]);

  if (couple.loading) return <PageLoading />;

  return (
    <main className="page">
      <div className="page-head">
        <h1>{t("space.title")}</h1>
        <p>{t("space.subtitle")}</p>
      </div>

      {!couple.coupleId ? (
        <EmptyState illustration="14-duo-a-creer" title={t("space.noCoupleTitle")} text={t("space.noCoupleText")}>
          <Link className="btn" to="/inviter">{t("home.invite")}</Link>
        </EmptyState>
      ) : (
        <div className="duo">
          <div className="avatars"><Avatar name={profile?.display_name ?? ""} me /><Avatar name={couple.partner?.name ?? ""} /></div>
          <div>
            <strong>{profile?.display_name} & {couple.partner?.name}</strong>
            {couple.since && <div className="muted small">{t("space.since", { date: formatDate(couple.since) })}</div>}
          </div>
        </div>
      )}

      <section className="stack">
        <h2>{t("space.history")}</h2>
        {error && <Alert>{t("net.offline")}</Alert>}
        {history === null ? <Loading /> : history.length === 0 ? (
          <p className="muted">{t("space.historyEmpty")}</p>
        ) : (
          <ul className="list">
            {history.map((h) => {
              const kept = h.session_players.length === 2 && h.session_players.every((p) => p.keep_memory);
              const former = h.couple_id !== couple.coupleId;
              return (
                <li key={h.id}>
                  <Link className="list-item" to={`/partie/${h.id}`}>
                    <Icon name="cards" />
                    <span className="list-item__body">
                      <strong>{h.games?.title}</strong>
                      <span className="muted small">
                        {formatDate(h.ended_at ?? h.created_at)} · {h.status === "ended" ? t("game.endTitle") : kept ? t("space.kept") : t("space.notKept")}
                        {former && <> · {t("space.separated")}</>}
                      </span>
                    </span>
                    <Icon name="arrow-right" />
                  </Link>
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section className="card card--flat">
        <h3 className="row"><Icon name="lock" /> {t("space.private")}</h3>
        <p className="muted">{t("space.privateText")}</p>
      </section>
    </main>
  );
}

export function Settings() {
  const { profile, updateProfile, signOut, session } = useAuth();
  const couple = useCouple();
  const [name, setName] = useState(profile?.display_name ?? "");
  const [form, setForm] = useState<WordForm>(profile?.word_form ?? "n");
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    setName(profile?.display_name ?? "");
    setForm(profile?.word_form ?? "n");
  }, [profile?.display_name, profile?.word_form]);

  async function save(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    const err = await updateProfile({ display_name: name.trim(), word_form: form });
    setBusy(false);
    setError(err ? errorMessage("unexpected") : null);
    setSaved(!err);
    setTimeout(() => setSaved(false), 2000);
  }

  async function toggle(key: "reduced_motion" | "intimate_opt_in", value: boolean) {
    const err = await updateProfile({ [key]: value });
    if (err) setError(errorMessage("unexpected"));
  }

  async function leave() {
    if (!window.confirm(t("settings.leaveConfirm"))) return;
    const res = await rpc("leave_couple");
    if (!res.ok) setError(errorMessage(res.error));
    await couple.refresh();
  }

  if (!profile) return <PageLoading />;

  return (
    <main className="page">
      <div className="page-head"><h1>{t("settings.title")}</h1></div>
      {error && <Alert>{error}</Alert>}

      <form className="card stack" onSubmit={save}>
        <h2>{t("settings.profile")}</h2>
        <p className="muted small">{session?.user.email}</p>
        <div className="field">
          <label htmlFor="st-name">{t("settings.name")}</label>
          <input id="st-name" className="input" required maxLength={40} value={name} onChange={(e) => setName(e.target.value)} />
        </div>
        <WordFormField value={form} onChange={setForm} />
        <button className="btn" type="submit" disabled={busy || !name.trim()}>{saved ? t("common.saved") : busy ? t("common.sending") : t("settings.save")}</button>
      </form>

      <section className="card stack">
        <h2>{t("settings.comfort")}</h2>
        <label className="switch">
          <span>{t("settings.reducedMotion")}</span>
          <input type="checkbox" role="switch" checked={profile.reduced_motion} onChange={(e) => toggle("reduced_motion", e.target.checked)} />
        </label>
      </section>

      <section className="card stack">
        <h2>{t("settings.privacy")}</h2>
        <p className="muted small">{t("settings.privacyText")}</p>
        <label className="switch">
          <span>{t("settings.intimate")}<br /><span className="muted small">{t("settings.intimateHint")}</span></span>
          <input type="checkbox" role="switch" checked={profile.intimate_opt_in} onChange={(e) => toggle("intimate_opt_in", e.target.checked)} />
        </label>
      </section>

      <section className="card stack">
        <h2>{t("settings.duo")}</h2>
        {couple.coupleId ? (
          <>
            <p>{t("settings.duoWith", { name: couple.partner?.name ?? "" })}</p>
            <button className="btn btn--danger" onClick={leave}>{t("settings.leave")}</button>
          </>
        ) : (
          <>
            <p className="muted">{t("settings.noDuo")}</p>
            <Link className="btn btn--secondary" to="/inviter">{t("home.invite")}</Link>
          </>
        )}
      </section>

      <section className="card stack">
        <h2>{t("settings.notifications")}</h2>
        <p className="muted small">{t("settings.notificationsSoon")}</p>
      </section>

      <section className="card stack">
        <h2>{t("settings.account")}</h2>
        <button className="btn btn--secondary" onClick={() => void signOut()}><Icon name="logout" />{t("settings.logout")}</button>
        <details className="rules">
          <summary>{t("settings.delete")}</summary>
          <p className="muted small" style={{ paddingBottom: 12 }}>{t("settings.deleteSoon")}</p>
        </details>
      </section>

      <section className="card card--flat stack">
        <h2>{t("settings.help")}</h2>
        <p className="muted small">{t("app.tagline")}</p>
        <p className="muted small">{t("settings.version", { v: __APP_VERSION__ })}</p>
      </section>
    </main>
  );
}
