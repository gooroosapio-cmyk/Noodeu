import { useEffect, useState, type FormEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router";
import { t } from "../i18n";
import { rpc } from "../lib/supabase";
import { errorMessage } from "../lib/errors";
import { useOnline } from "../lib/useOnline";
import { useAuth } from "../auth/AuthProvider";
import { Avatar } from "../components/Avatar";
import { SubPage } from "../components/AppShell";
import { Alert, ConfirmDialog, Icon, Illustration, formatDate, useToast } from "../components/ui";
import { useDuo } from "./DuoProvider";

export function InvitePage() {
  const [params] = useSearchParams();
  const { active, invitations } = useDuo();
  const navigate = useNavigate();
  const [tab, setTab] = useState<"invite" | "join">(params.get("code") || invitations.incoming ? "join" : "invite");
  const [justPaired, setJustPaired] = useState(false);

  useEffect(() => {
    if (active && justPaired) navigate("/salon", { replace: true });
  }, [active, justPaired, navigate]);

  return (
    <SubPage backTo="/accueil">
      <main className="page page--bare page--narrow">
        <div className="page-header">
          <h1 className="t-page">{t("invite.title")}</h1>
          <p>{t("invite.subtitle")}</p>
        </div>
        {active ? (
          <>
            <Alert kind="info">{t("invite.alreadyDuo")}</Alert>
            <Link className="btn btn--secondary" to="/salon">{t("nav.space")}</Link>
          </>
        ) : (
          <>
            <div className="chips" role="tablist" aria-label={t("invite.title")}>
              <button className="chip" role="tab" aria-selected={tab === "invite"} aria-pressed={tab === "invite"} onClick={() => setTab("invite")}>{t("invite.tabInvite")}</button>
              <button className="chip" role="tab" aria-selected={tab === "join"} aria-pressed={tab === "join"} onClick={() => setTab("join")}>{t("invite.tabJoin")}</button>
            </div>
            {tab === "invite" ? <InvitePanel onPaired={() => setJustPaired(true)} /> : <JoinPanel initialCode={params.get("code") ?? ""} />}
          </>
        )}
      </main>
    </SubPage>
  );
}

export function useInviteActions() {
  const { invitations, refresh } = useDuo();
  const toast = useToast();
  const out = invitations.outgoing;
  const link = out ? `${window.location.origin}/rejoindre?code=${out.code}` : "";

  async function share() {
    if (!out) return;
    const text = t("invite.shareText", { code: out.code });
    if (navigator.share) {
      try {
        await navigator.share({ title: "Noodeu", text, url: link });
        toast(t("invite.shared"));
      } catch {
        /* partage annulé : pas de faux succès */
      }
    } else {
      await copy(`${text}\n${link}`);
    }
  }
  async function copy(value = out?.code ?? "") {
    try {
      await navigator.clipboard.writeText(value);
      toast(t("invite.copied"));
    } catch {
      toast(errorMessage("unexpected"));
    }
  }
  async function revoke() {
    if (!out) return;
    const res = await rpc("revoke_invitation", { p_invitation: out.id });
    await refresh();
    toast(res.ok ? t("invite.revoked") : errorMessage(res.error));
  }
  async function regenerate() {
    const res = await rpc("regenerate_invitation");
    await refresh();
    toast(res.ok ? t("invite.regenerated") : errorMessage(res.error));
  }
  return { out, share, copy, revoke, regenerate };
}

export function InvitePanel({ onPaired }: { onPaired?: () => void }) {
  const { refresh } = useDuo();
  const online = useOnline();
  const { out, share, copy, revoke, regenerate } = useInviteActions();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirmRevoke, setConfirmRevoke] = useState(false);

  async function create() {
    if (busy) return;
    setBusy(true);
    setError(null);
    const res = await rpc("create_invitation");
    if (!res.ok) setError(errorMessage(res.error));
    await refresh();
    setBusy(false);
  }

  if (out?.status === "claimed") return <PendingRequest onPaired={onPaired} />;

  if (!out || out.expired) {
    return (
      <section className="card card--lg stack stack--4">
        {out?.expired && <Alert kind="info">{errorMessage("expired")}</Alert>}
        {error && <Alert>{error}</Alert>}
        <button className="btn" disabled={busy || !online} onClick={create}>{busy ? t("common.sending") : t("invite.create")}</button>
      </section>
    );
  }

  return (
    <section className="stack stack--4">
      <div className="card card--lg stack stack--2 center">
        <h2 className="t-card">{t("invite.yourCode")}</h2>
        <p className="code-box" aria-label={out.code.split("").join(" ")} style={{ width: "100%" }}>{out.code}</p>
        <p className="t-meta">{t("invite.expires", { date: formatDate(out.expires_at, true) })}</p>
      </div>
      <button className="btn" onClick={() => void share()}><Icon name="share" />{t("invite.share")}</button>
      <button className="btn btn--secondary" onClick={() => void copy()}><Icon name="copy" />{t("invite.copy")}</button>
      <div className="row row--wrap" style={{ justifyContent: "center" }}>
        <button className="btn btn--quiet btn--auto btn--sm" onClick={() => void regenerate()}>{t("invite.regenerate")}</button>
        <button className="btn btn--quiet btn--auto btn--sm" style={{ color: "var(--c-danger)" }} onClick={() => setConfirmRevoke(true)}>{t("invite.revoke")}</button>
      </div>
      {confirmRevoke && (
        <ConfirmDialog title={t("invite.revoke")} text={t("invite.revokeText")} confirmLabel={t("invite.revoke")} danger
          onCancel={() => setConfirmRevoke(false)} onConfirm={() => { setConfirmRevoke(false); void revoke(); }} />
      )}
    </section>
  );
}

/** Seconde confirmation, côté personne qui a invité. */
export function PendingRequest({ onPaired }: { onPaired?: () => void }) {
  const { invitations, refresh } = useDuo();
  const { profile } = useAuth();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const out = invitations.outgoing;
  if (!out || out.status !== "claimed") return null;
  const name = out.claimer_name || "?";

  async function respond(accept: boolean) {
    if (busy) return;
    setBusy(true);
    setError(null);
    const res = await rpc("respond_to_claim", { p_invitation: out!.id, p_accept: accept });
    if (!res.ok) setError(errorMessage(res.error));
    else if (accept) {
      toast(t("invite.paired"));
      onPaired?.();
    }
    await refresh();
    setBusy(false);
  }

  return (
    <section className="card card--lg stack stack--4 enter" aria-live="polite">
      <div className="row">
        <Avatar name={profile?.display_name ?? ""} path={profile?.avatar_path} size={48} me />
        <Avatar name={name} size={48} />
      </div>
      <h2 className="t-section">{t("invite.requestTitle", { name })}</h2>
      <p className="muted">{t("invite.requestText")}</p>
      {error && <Alert>{error}</Alert>}
      <button className="btn" disabled={busy} onClick={() => respond(true)}>{t("invite.accept", { name })}</button>
      <button className="btn btn--secondary" disabled={busy} onClick={() => respond(false)}>{t("invite.decline")}</button>
    </section>
  );
}

export function JoinPanel({ initialCode }: { initialCode: string }) {
  const { invitations, refresh } = useDuo();
  const online = useOnline();
  const [code, setCode] = useState(initialCode);
  const [preview, setPreview] = useState<{ id: string; inviter_name: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const incoming = invitations.incoming;
  const normalized = code.replace(/[^A-Za-z0-9]/g, "");

  async function check(e?: FormEvent) {
    e?.preventDefault();
    if (busy || normalized.length !== 8) return;
    setBusy(true);
    setError(null);
    const res = await rpc<{ id: string; inviter_name: string }>("preview_invitation", { p_code: normalized });
    if (res.ok) setPreview({ id: res.id, inviter_name: res.inviter_name });
    else setError(res.error);
    setBusy(false);
  }

  async function claim() {
    if (busy) return;
    setBusy(true);
    const res = await rpc("claim_invitation", { p_code: normalized });
    if (!res.ok) setError(res.error);
    await refresh();
    setBusy(false);
  }

  async function withdraw() {
    if (!incoming || busy) return;
    setBusy(true);
    await rpc("withdraw_claim", { p_invitation: incoming.id });
    setPreview(null);
    await refresh();
    setBusy(false);
  }

  useEffect(() => {
    // Lien d'invitation : on vérifie le code, sans jamais accepter automatiquement.
    if (initialCode && !preview && !incoming) void check();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (incoming) {
    return (
      <section className="card card--lg stack stack--4 center enter" aria-live="polite">
        <Illustration name="09-attente-douce" className="public__art" />
        <h2 className="t-section">{t("invite.waitingTitle")}</h2>
        <p className="muted">{t("invite.waitingText", { name: incoming.inviter_name })}</p>
        <button className="btn btn--secondary" disabled={busy} onClick={withdraw}>{t("invite.withdraw")}</button>
      </section>
    );
  }

  if (preview) {
    return (
      <section className="card card--lg stack stack--4 enter">
        <div className="row"><Avatar name={preview.inviter_name} size={56} /></div>
        <h2 className="t-section">{t("invite.joinConfirmTitle", { name: preview.inviter_name })}</h2>
        <p className="muted">{t("invite.joinConfirmText", { name: preview.inviter_name })}</p>
        {error && <Alert>{errorMessage(error)}</Alert>}
        <button className="btn" disabled={busy || !online} onClick={claim}>{t("invite.joinConfirm", { name: preview.inviter_name })}</button>
        <button className="btn btn--secondary" disabled={busy} onClick={() => setPreview(null)}>{t("common.cancel")}</button>
      </section>
    );
  }

  return (
    <form className="card card--lg stack stack--4" onSubmit={check}>
      {error === "expired" && <Illustration name="15-invitation-expiree" className="public__art" />}
      <div className="field">
        <label className="field__label" htmlFor="code">{t("invite.joinLabel")}</label>
        <input id="code" className="input input--code" value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          onPaste={(e) => { e.preventDefault(); setCode(e.clipboardData.getData("text").trim().toUpperCase().slice(0, 12)); }}
          autoComplete="one-time-code" autoCapitalize="characters" spellCheck={false} maxLength={12} placeholder="XXXX-XXXX"
          aria-invalid={Boolean(error)} aria-describedby={error ? "code-hint code-error" : "code-hint"} />
        <span id="code-hint" className="field__hint">{t("invite.joinHint")}</span>
        {error && <span id="code-error" className="field__error" role="alert">{errorMessage(error)}</span>}
      </div>
      <button className="btn" type="submit" disabled={busy || !online || normalized.length !== 8}>{busy ? t("common.sending") : t("invite.joinCheck")}</button>
    </form>
  );
}
