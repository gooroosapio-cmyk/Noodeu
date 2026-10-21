import { useState, type FormEvent } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router";
import { t } from "../i18n";
import { supabase } from "../lib/supabase";
import { authErrorMessage } from "../lib/errors";
import { Alert, Illustration, Logo } from "../components/ui";
import { useAuth } from "./AuthProvider";
import type { WordForm } from "../lib/types";

const googleEnabled = import.meta.env.VITE_AUTH_GOOGLE === "true";

/** Retour après connexion : conserve une invitation en cours (/rejoindre?code=…). */
function useNextPath() {
  const params = new URLSearchParams(useLocation().search);
  const next = params.get("next");
  return next && next.startsWith("/") && !next.startsWith("//") ? next : "/accueil";
}

export function Welcome() {
  const { session } = useAuth();
  const next = useNextPath();
  const suffix = next !== "/accueil" ? `?next=${encodeURIComponent(next)}` : "";
  if (session) return <Navigate to={next} replace />;
  return (
    <main className="page page--bare">
      <Logo width={150} />
      <Illustration name="01-connexion-a-deux" className="illustration--hero" eager />
      <div className="page-head center">
        <h1>{t("welcome.title")}</h1>
        <p>{t("welcome.subtitle")}</p>
      </div>
      <div className="stack">
        <Link className="btn" to={`/inscription${suffix}`}>{t("welcome.create")}</Link>
        <Link className="btn btn--secondary" to={`/connexion${suffix}`}>{t("welcome.login")}</Link>
      </div>
    </main>
  );
}

export function AuthForm({ mode }: { mode: "signup" | "login" }) {
  const { session } = useAuth();
  const navigate = useNavigate();
  const next = useNextPath();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [adult, setAdult] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  if (session) return <Navigate to={next} replace />;

  const redirectTo = `${window.location.origin}${next}`;

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    setInfo(null);
    if (mode === "signup") {
      const { data, error } = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: { data: { display_name: name.trim() }, emailRedirectTo: redirectTo },
      });
      if (error) setError(authErrorMessage(error.message));
      else if (!data.session) setInfo(t("auth.checkEmail", { email: email.trim() }));
      else navigate(next, { replace: true });
    } else {
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (error) setError(authErrorMessage(error.message));
      else navigate(next, { replace: true });
    }
    setBusy(false);
  }

  async function google() {
    setError(null);
    const { error } = await supabase.auth.signInWithOAuth({ provider: "google", options: { redirectTo } });
    if (error) setError(authErrorMessage(error.message));
  }

  async function forgot() {
    if (!email.trim()) {
      setError(t("auth.email"));
      return;
    }
    await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${window.location.origin}/parametres` });
    setInfo(t("auth.resetSent"));
  }

  const signup = mode === "signup";
  return (
    <main className="page page--bare">
      <div className="topbar">
        <Link className="icon-btn" to="/" aria-label={t("common.back")}>←</Link>
        <Logo width={120} />
        <span style={{ width: 44 }} />
      </div>
      <h1>{signup ? t("auth.signupTitle") : t("auth.loginTitle")}</h1>
      <form className="stack" onSubmit={submit} noValidate={false}>
        {signup && (
          <div className="field">
            <label htmlFor="name">{t("auth.firstName")}</label>
            <input id="name" className="input" required maxLength={40} autoComplete="given-name" value={name} onChange={(e) => setName(e.target.value)} aria-describedby="name-hint" />
            <span id="name-hint" className="hint">{t("auth.firstNameHint")}</span>
          </div>
        )}
        <div className="field">
          <label htmlFor="email">{t("auth.email")}</label>
          <input id="email" className="input" type="email" required inputMode="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="password">{t("auth.password")}</label>
          <input id="password" className="input" type="password" required minLength={8} autoComplete={signup ? "new-password" : "current-password"} value={password} onChange={(e) => setPassword(e.target.value)} aria-describedby="pw-hint" />
          {signup && <span id="pw-hint" className="hint">{t("auth.passwordHint")}</span>}
        </div>
        {signup && (
          <label className="choice">
            <input type="checkbox" required checked={adult} onChange={(e) => setAdult(e.target.checked)} />
            <span>{t("auth.adult")}</span>
          </label>
        )}
        {error && <Alert>{error}</Alert>}
        {info && <Alert kind="info">{info}</Alert>}
        <button className="btn" type="submit" disabled={busy || (signup && (!adult || !name.trim()))}>
          {busy ? t("common.sending") : signup ? t("auth.signup") : t("auth.login")}
        </button>
        {!signup && <button type="button" className="btn btn--ghost" onClick={forgot}>{t("auth.forgot")}</button>}
      </form>
      {googleEnabled && (
        <>
          <p className="center muted">{t("auth.or")}</p>
          <button className="btn btn--secondary" onClick={google}>{t("auth.google")}</button>
        </>
      )}
      <Link className="btn btn--ghost" to={`${signup ? "/connexion" : "/inscription"}${next !== "/accueil" ? `?next=${encodeURIComponent(next)}` : ""}`}>
        {signup ? t("auth.toLogin") : t("auth.toSignup")}
      </Link>
    </main>
  );
}

/** Complète le profil (prénom, accord des mots) quand il manque, par exemple après Google. */
export function Onboarding() {
  const { profile, updateProfile } = useAuth();
  const [name, setName] = useState(profile?.display_name ?? "");
  const [form, setForm] = useState<WordForm>(profile?.word_form ?? "n");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    const err = await updateProfile({ display_name: name.trim(), word_form: form });
    setBusy(false);
    if (err) setError(authErrorMessage(err));
  }

  return (
    <main className="page page--bare">
      <Logo width={120} />
      <div className="page-head">
        <h1>{t("onboarding.title")}</h1>
        <p>{t("onboarding.subtitle")}</p>
      </div>
      <form className="stack stack--lg" onSubmit={submit}>
        <div className="field">
          <label htmlFor="ob-name">{t("auth.firstName")}</label>
          <input id="ob-name" className="input" required maxLength={40} value={name} onChange={(e) => setName(e.target.value)} />
          <span className="hint">{t("auth.firstNameHint")}</span>
        </div>
        <WordFormField value={form} onChange={setForm} />
        {error && <Alert>{error}</Alert>}
        <button className="btn" type="submit" disabled={busy || !name.trim()}>{busy ? t("common.sending") : t("onboarding.save")}</button>
      </form>
    </main>
  );
}

export function WordFormField({ value, onChange }: { value: WordForm; onChange: (v: WordForm) => void }) {
  return (
    <fieldset>
      <legend className="field"><span style={{ fontWeight: 600 }}>{t("onboarding.form")}</span></legend>
      {(["f", "m", "n"] as const).map((f) => (
        <label key={f} className="choice">
          <input type="radio" name="word_form" value={f} checked={value === f} onChange={() => onChange(f)} />
          <span>{t(`onboarding.form.${f}`)}</span>
        </label>
      ))}
    </fieldset>
  );
}

/** Le prénom est le seul élément indispensable (connexion Google : il n'est pas encore connu). */
export function needsOnboarding(profile: { display_name: string } | null) {
  return Boolean(profile) && !profile!.display_name.trim();
}
