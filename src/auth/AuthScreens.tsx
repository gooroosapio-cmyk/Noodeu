import { useRef, useState, type FormEvent } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router";
import { t } from "../i18n";
import { supabase } from "../lib/supabase";
import { authErrorMessage } from "../lib/errors";
import { Alert, Icon, Illustration, Logo } from "../components/ui";
import { useAuth } from "./AuthProvider";
import type { WordForm } from "../lib/types";

/** Destination après connexion (ex. /rejoindre?code=…). Uniquement un chemin interne. */
function useNextPath() {
  const params = new URLSearchParams(useLocation().search);
  const next = params.get("next");
  return next && next.startsWith("/") && !next.startsWith("//") ? next : "/accueil";
}

/** Emplacement réservé : aucun appel OAuth tant que le propriétaire n'a pas branché Google. */
function GooglePlaceholder() {
  return <div className="stack stack--2">
    <button className="btn btn--secondary" type="button" disabled aria-describedby="google-pending">
      {t("auth.google")}
    </button>
    <p id="google-pending" className="t-small muted center">Connexion Google bientôt disponible. Utilise ton adresse e-mail pour le moment.</p>
  </div>;
}

export function Welcome() {
  const { session } = useAuth();
  const next = useNextPath();
  const suffix = next !== "/accueil" ? `?next=${encodeURIComponent(next)}` : "";
  if (session) return <Navigate to={next} replace />;
  return (
    <main className="public">
      <div className="row" style={{ justifyContent: "center" }}><Logo width={120} /></div>
      <div className="public__main">
        <Illustration name="01-connexion-a-deux" className="public__art" eager />
        <div className="stack stack--2">
          <h1 className="t-display">{t("welcome.title")}</h1>
          <p className="muted">{t("welcome.subtitle")}</p>
        </div>
        <div className="public__actions">
          <GooglePlaceholder />
          <div className="divider">{t("auth.or")}</div>
          <Link className="btn" to={`/inscription${suffix}`}>{t("welcome.create")}</Link>
          <Link className="btn btn--quiet" to={`/connexion${suffix}`}>{t("welcome.login")}</Link>
        </div>
      </div>
      <footer className="footer-credit">{t("app.credit")}</footer>
    </main>
  );
}

export function AuthForm({ mode }: { mode: "signup" | "login" }) {
  const { session } = useAuth();
  const navigate = useNavigate();
  const next = useNextPath();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const authLock = useRef(false);
  const [name, setName] = useState("");
  const [adult, setAdult] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  if (session) return <Navigate to={next} replace />;
  const signup = mode === "signup";
  const suffix = next !== "/accueil" ? `?next=${encodeURIComponent(next)}` : "";

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (authLock.current) return;
    authLock.current = true;
    setBusy(true);
    setError(null);
    setInfo(null);
    try {
    if (signup) {
      const { data, error } = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: { data: { display_name: name.trim() }, emailRedirectTo: `${window.location.origin}${next}` },
      });
      if (error) setError(authErrorMessage(error.message));
      else if (!data.session) setInfo(t("auth.checkEmail", { email: email.trim() }));
      else navigate(next, { replace: true });
    } else {
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (error) setError(authErrorMessage(error.message));
      else navigate(next, { replace: true });
    }
    } catch { setError("Connexion impossible pour le moment. Réessaie dans un instant."); }
    finally { authLock.current = false; setBusy(false); }
  }

  async function forgot() {
    if (!email.trim()) {
      setError(t("auth.emailRequired"));
      return;
    }
    if(authLock.current) return;
    authLock.current=true;setBusy(true);setError(null);setInfo(null);
    try {
      const {error}=await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${window.location.origin}/reglages/profil` });
      if(error)setError(authErrorMessage(error.message));else setInfo(t("auth.resetSent"));
    } catch {setError("Envoi impossible pour le moment. Réessaie dans un instant.");}
    finally {authLock.current=false;setBusy(false);}
  }

  return (
    <main className={`page page--bare page--narrow auth-page ${signup ? "auth-page--signup" : "auth-page--login"}`}>
      <header className="topbar" style={{ padding: 0 }}>
        <Link className="icon-btn icon-btn--soft" to={`/${suffix}`} aria-label={t("common.back")}><Icon name="arrow-left" /></Link>
        <Logo width={96} />
      </header>
      <div className="auth-heading"><h1>{signup ? "Créer un compte" : "Bonjour"}</h1><p>{signup ? "Un espace pour vous retrouver à deux." : "Connecte-toi à ton espace Noodeu."}</p></div>
      <form className="stack stack--4" onSubmit={submit}>
        {signup && (
          <div className="field">
            <label className="field__label" htmlFor="name">{t("auth.firstName")}</label>
            <div className="auth-input"><Icon name="user" size={20} /><input id="name" className="input" required maxLength={40} autoComplete="given-name" value={name} onChange={(e) => setName(e.target.value)} aria-describedby="name-hint" disabled={busy} /></div>
            <span id="name-hint" className="field__hint">{t("auth.firstNameHint")}</span>
          </div>
        )}
        <div className="field">
          <label className="field__label" htmlFor="email">{t("auth.email")}</label>
          <div className="auth-input"><Icon name="send" size={20} /><input id="email" className="input" type="email" required inputMode="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} disabled={busy} spellCheck={false} autoCapitalize="none" /></div>
        </div>
        <div className="field">
          <label className="field__label" htmlFor="password">{t("auth.password")}</label>
          <div className="auth-input auth-input--password"><Icon name="lock" size={20} /><input id="password" className="input" type={showPassword ? "text" : "password"} required minLength={8} autoComplete={signup ? "new-password" : "current-password"}
            value={password} onChange={(e) => setPassword(e.target.value)} aria-describedby={signup ? "pw-hint" : undefined} disabled={busy} /><button type="button" className="icon-btn" aria-label={showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe"} aria-pressed={showPassword} onClick={() => setShowPassword(v=>!v)}><Icon name={showPassword ? "eye-off" : "eye"} size={20} /></button></div>
          {signup && <span id="pw-hint" className="field__hint">{t("auth.passwordHint")}</span>}
        </div>
        {signup && (
          <label className="choice">
            <input type="checkbox" required checked={adult} onChange={(e) => setAdult(e.target.checked)} />
            <span>{t("auth.adult")}</span>
          </label>
        )}
        {error && <Alert>{error}</Alert>}
        {info && <Alert kind="info">{info}</Alert>}
        <button className="btn auth-submit" type="submit" disabled={busy || (signup && (!adult || !name.trim()))}>
          <span>{busy ? t("common.sending") : signup ? t("auth.signup") : t("auth.login")}</span><span className="auth-submit__arrow"><Icon name="arrow-right" /></span>
        </button>
        {!signup && <button type="button" className="btn btn--quiet" disabled={busy} onClick={forgot}>{t("auth.forgot")}</button>}
      </form>
      <div className="auth-google"><GooglePlaceholder /></div>
      <Link className="btn btn--quiet" to={`${signup ? "/connexion" : "/inscription"}${suffix}`}>{signup ? t("auth.toLogin") : t("auth.toSignup")}</Link>
    </main>
  );
}

/** Complète le profil quand le prénom manque (par exemple après une connexion Google). */
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
    if (err) setError(t("profile.error"));
  }

  return (
    <main className="page page--bare page--narrow">
      <div style={{ paddingTop: 16 }}><Logo width={104} /></div>
      <div className="page-header">
        <h1 className="t-page">{t("onboarding.title")}</h1>
        <p>{t("onboarding.subtitle")}</p>
      </div>
      <form className="stack stack--6" onSubmit={submit}>
        <div className="field">
          <label className="field__label" htmlFor="ob-name">{t("auth.firstName")}</label>
          <input id="ob-name" className="input" required maxLength={40} value={name} onChange={(e) => setName(e.target.value)} aria-describedby="ob-hint" />
          <span id="ob-hint" className="field__hint">{t("auth.firstNameHint")}</span>
        </div>
        <WordFormField value={form} onChange={setForm} />
        {error && <Alert>{error}</Alert>}
        <button className="btn" type="submit" disabled={busy || !name.trim()}>{busy ? t("common.sending") : t("onboarding.save")}</button>
      </form>
    </main>
  );
}

/** Forme des mots dans les jeux : jamais déduite du nom ou de la photo. */
export function WordFormField({ value, onChange }: { value: WordForm; onChange: (v: WordForm) => void }) {
  return (
    <fieldset>
      <legend>{t("form.legend")}</legend>
      {(["f", "m", "n"] as const).map((f) => (
        <label key={f} className="choice">
          <input type="radio" name="word_form" value={f} checked={value === f} onChange={() => onChange(f)} />
          <span className="choice__text">
            <span>{t(`form.${f}`)}</span>
            <span className="t-small muted">{t(`form.${f}Ex`)}</span>
          </span>
        </label>
      ))}
    </fieldset>
  );
}

/** Le prénom est le seul élément indispensable. */
export function needsOnboarding(profile: { display_name: string } | null) {
  return Boolean(profile) && !profile!.display_name.trim();
}
