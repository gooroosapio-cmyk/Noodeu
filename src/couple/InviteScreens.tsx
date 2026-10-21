import { useEffect, useState, type FormEvent } from "react";
import { Link, useNavigate, useSearchParams } from "react-router";
import { t } from "../i18n";
import { rpc } from "../lib/supabase";
import { errorMessage } from "../lib/errors";
import { useOnline } from "../lib/useOnline";
import { Alert, Avatar, Icon, Illustration, formatDate } from "../components/ui";
import { useAuth } from "../auth/AuthProvider";
import { useCouple } from "./CoupleProvider";

/** Page « Inviter / J'ai un code ». */
export function InvitePage() {
  const [params] = useSearchParams();
  const { coupleId } = useCouple();
  const navigate = useNavigate();
  const [tab, setTab] = useState<"invite" | "join">(params.get("code") ? "join" : "invite");
  useEffect(() => {
    if (coupleId) navigate("/notre-espace", { replace: true });
  }, [coupleId, navigate]);

  return (
    <main className="page">
      <div className="topbar">
        <Link className="icon-btn" to="/accueil"><Icon name="arrow-left" label={t("common.back")} /></Link>
      </div>
      <div className="page-head">
        <h1>{t("invite.title")}</h1>
        <p>{t("invite.subtitle")}</p>
      </div>
      <div className="tabs" role="tablist">
        <button role="tab" aria-selected={tab === "invite"} onClick={() => setTab("invite")}>{t("invite.tabInvite")}</button>
        <button role="tab" aria-selected={tab === "join"} onClick={() => setTab("join")}>{t("invite.tabJoin")}</button>
      </div>
      {tab === "invite" ? <InvitePanel /> : <JoinPanel initialCode={params.get("code") ?? ""} />}
      <Link className="btn btn--ghost" to="/bibliotheques">{t("invite.exploreMeanwhile")}</Link>
    </main>
  );
}

export function InvitePanel() {
  const { invitations, refresh } = useCouple();
  const online = useOnline();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const out = invitations.outgoing;

  async function act(fn: () => Promise<{ ok: boolean; error?: string }>) {
    if (busy) return;
    setBusy(true);
    setError(null);
    const res = await fn();
    if (!res.ok) setError(errorMessage(res.error));
    await refresh();
    setBusy(false);
  }

  if (out?.status === "claimed") return <PendingRequest />;

  if (!out || out.expired) {
    return (
      <section className="card stack center">
        <Illustration name={out?.expired ? "15-invitation-expiree" : "02-invitation"} className="illustration--hero" />
        {out?.expired && <Alert kind="info">{errorMessage("expired")}</Alert>}
        {error && <Alert>{error}</Alert>}
        <button className="btn" disabled={busy || !online} onClick={() => act(() => rpc("create_invitation"))}>
          {busy ? t("common.sending") : t("invite.create")}
        </button>
        <p className="muted small">{t("invite.onlyOne")}</p>
      </section>
    );
  }

  const link = `${window.location.origin}/rejoindre?code=${out.code}`;
  async function share() {
    const text = t("invite.shareText", { code: out!.code });
    if (navigator.share) {
      try {
        await navigator.share({ title: "Noodeu", text, url: link });
      } catch {
        /* partage annulé */
      }
    } else {
      await copy(`${text}\n${link}`);
    }
  }
  async function copy(value = out!.code) {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setError(t("invite.copy"));
    }
  }

  return (
    <section className="card stack">
      <h2 className="center">{t("invite.yourCode")}</h2>
      <p className="code-box" aria-label={out.code.split("").join(" ")}>{out.code}</p>
      <p className="center muted small">{t("invite.expires", { date: formatDate(out.expires_at, true) })}</p>
      <button className="btn" onClick={share}><Icon name="share" />{t("invite.share")}</button>
      <button className="btn btn--secondary" onClick={() => copy()}>
        <Icon name={copied ? "check" : "copy"} />{copied ? t("invite.copied") : t("invite.copy")}
      </button>
      {error && <Alert>{error}</Alert>}
      <p className="muted small center"><Icon name="info" size={16} /> {t("invite.onlyOne")}</p>
      <button className="btn btn--ghost" disabled={busy} onClick={() => act(() => rpc("revoke_invitation", { p_invitation: out.id }))}>
        {t("invite.revoke")}
      </button>
    </section>
  );
}

/** Seconde confirmation, côté personne qui a invité. */
export function PendingRequest() {
  const { invitations, refresh } = useCouple();
  const { profile } = useAuth();
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
    await refresh();
    setBusy(false);
  }

  return (
    <section className="card stack center enter" aria-live="polite">
      <div className="avatars"><Avatar name={profile?.display_name ?? "?"} me /><Avatar name={name} /></div>
      <h2>{t("invite.requestTitle", { name })}</h2>
      <p className="muted">{t("invite.requestText")}</p>
      {error && <Alert>{error}</Alert>}
      <button className="btn" disabled={busy} onClick={() => respond(true)}>{t("invite.accept")}</button>
      <button className="btn btn--secondary" disabled={busy} onClick={() => respond(false)}>{t("invite.decline")}</button>
    </section>
  );
}

export function JoinPanel({ initialCode }: { initialCode: string }) {
  const { invitations, refresh } = useCouple();
  const online = useOnline();
  const [code, setCode] = useState(initialCode);
  const [preview, setPreview] = useState<{ id: string; inviter_name: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<{ code: string } | null>(null);
  const incoming = invitations.incoming;

  async function check(e?: FormEvent) {
    e?.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    const res = await rpc<{ id: string; inviter_name: string }>("preview_invitation", { p_code: code });
    if (res.ok) setPreview({ id: res.id, inviter_name: res.inviter_name });
    else setError({ code: res.error });
    setBusy(false);
  }

  async function claim() {
    if (busy) return;
    setBusy(true);
    const res = await rpc("claim_invitation", { p_code: code });
    if (!res.ok) setError({ code: res.error });
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
    if (initialCode && !preview && !incoming) void check();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (incoming) {
    return (
      <section className="card stack center enter" aria-live="polite">
        <Illustration name="09-attente-douce" className="illustration--hero" />
        <h2>{t("invite.waitingTitle")}</h2>
        <p className="muted">{t("invite.waitingText", { name: incoming.inviter_name })}</p>
        <button className="btn btn--secondary" disabled={busy} onClick={withdraw}>{t("invite.withdraw")}</button>
      </section>
    );
  }

  if (preview) {
    return (
      <section className="card stack center enter">
        <Illustration name="03-duo-confirme" className="illustration--hero" />
        <h2>{t("invite.joinConfirmTitle", { name: preview.inviter_name })}</h2>
        <p className="muted">{t("invite.joinConfirmText", { name: preview.inviter_name })}</p>
        {error && <Alert>{errorMessage(error.code)}</Alert>}
        <button className="btn" disabled={busy || !online} onClick={claim}>{t("invite.joinConfirm", { name: preview.inviter_name })}</button>
        <button className="btn btn--secondary" disabled={busy} onClick={() => setPreview(null)}>{t("common.cancel")}</button>
      </section>
    );
  }

  const expired = error?.code === "expired";
  return (
    <form className="card stack" onSubmit={check}>
      {expired && <Illustration name="15-invitation-expiree" className="illustration--hero" />}
      <div className="field">
        <label htmlFor="code">{t("invite.joinLabel")}</label>
        <input
          id="code"
          className="input input--code"
          value={code}
          onChange={(e) => setCode(e.target.value.toUpperCase())}
          autoComplete="one-time-code"
          autoCapitalize="characters"
          spellCheck={false}
          maxLength={9}
          placeholder="XXXX-XXXX"
          aria-invalid={Boolean(error)}
          aria-describedby={error ? "code-error" : undefined}
        />
      </div>
      {error && <div id="code-error"><Alert>{errorMessage(error.code)}</Alert></div>}
      <button className="btn" type="submit" disabled={busy || !online || code.replace(/[^A-Za-z0-9]/g, "").length !== 8}>
        {busy ? t("common.sending") : t("invite.joinCheck")}
      </button>
    </form>
  );
}
