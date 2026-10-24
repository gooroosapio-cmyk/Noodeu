import { useEffect, useRef, useState, type FormEvent, type PointerEvent as ReactPointerEvent } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { supabase } from "../lib/supabase";
import { useAuth } from "../auth/AuthProvider";
import { WordFormField } from "../auth/AuthScreens";
import { Avatar, clearAvatarCache } from "../components/Avatar";
import { SubPage } from "../components/AppShell";
import { Alert, ConfirmDialog, Icon, PageLoading, Sheet, useToast } from "../components/ui";
import type { Profile, WordForm } from "../lib/types";
import { INTENSITIES } from "./catalog";

const COUNTRIES = ["FR", "BE", "CH", "CA"] as const;

export function Settings() {
  const { profile, updateProfile, signOut } = useAuth();
  const toast = useToast();
  const [error, setError] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [typed, setTyped] = useState("");
  const [deleting, setDeleting] = useState(false);
  const [adultAsk, setAdultAsk] = useState(false);
  const [adultCheck, setAdultCheck] = useState(false);

  if (!profile) return <PageLoading />;

  async function save(patch: Partial<Omit<Profile, "id">>) {
    const err = await updateProfile(patch);
    if (err) setError(t("profile.error"));
    else toast(t("common.saved"));
  }

  function toggle(key: "reduced_motion" | "intimate_opt_in", value: boolean) {
    // Activation du +18 : déclaration de majorité horodatée, demandée à chaque nouvelle activation.
    if (key === "intimate_opt_in" && value) {
      setAdultCheck(false);
      setAdultAsk(true);
      return;
    }
    void save(key === "intimate_opt_in" ? { intimate_opt_in: false, daily_adult: false } : { [key]: value });
  }

  const rem = profile.reminders;
  const hours = Array.from({ length: 24 }, (_, h) => h);

  async function deleteAccount() {
    setDeleting(true);
    setError(null);
    const { data, error: e } = await supabase.functions.invoke("delete-account", { body: { confirm: "SUPPRIMER" } });
    setDeleting(false);
    if (e || !(data as { ok?: boolean })?.ok) {
      setError(t("settings.deleteError"));
      setConfirmDelete(false);
      return;
    }
    await signOut();
  }

  return (
    <main className="page page--read">
      <div className="page-header"><h1 className="t-page">{t("settings.title")}</h1></div>
      {error && <Alert>{error}</Alert>}

      <section className="section">
        <h2 className="t-section">{t("settings.profile")}</h2>
        <div className="group">
          <Link className="group__row" to="/reglages/profil">
            <Avatar name={profile.display_name} path={profile.avatar_path} size={44} me />
            <span className="list-row__body"><span className="t-card">{profile.display_name}</span><span className="t-meta">{t("settings.editProfile")}</span></span>
            <span className="chev"><Icon name="arrow-right" size={20} /></span>
          </Link>
        </div>
      </section>

      <section className="section">
        <h2 className="t-section">{t("settings.preferences")}</h2>
        <div className="group">
          <label className="switch-row">
            <span className="switch-row__text"><span>{t("settings.reducedMotion")}</span><span className="t-meta">{t("settings.reducedMotionHint")}</span></span>
            <input className="switch" type="checkbox" role="switch" checked={profile.reduced_motion} onChange={(e) => void toggle("reduced_motion", e.target.checked)} />
          </label>
        </div>
      </section>

      <section className="section">
        <h2 className="t-section">{t("settings.privacy")}</h2>
        <div className="group">
          <label className="switch-row">
            <span className="switch-row__text"><span>{t("settings.intimate")}</span><span className="t-meta">{t("settings.intimateHint")}</span></span>
            <input className="switch" type="checkbox" role="switch" checked={profile.intimate_opt_in} onChange={(e) => void toggle("intimate_opt_in", e.target.checked)} />
          </label>
          {profile.intimate_opt_in && (
            <label className="switch-row">
              <span className="switch-row__text"><span>{t("settings.dailyAdult")}</span><span className="t-meta">{t("settings.dailyAdultHint")}</span></span>
              <input className="switch" type="checkbox" role="switch" checked={profile.daily_adult} onChange={(e) => void save({ daily_adult: e.target.checked })} />
            </label>
          )}
          <p className="t-meta group__note">{t("settings.noConsent")}</p>
          <details className="disclosure" style={{ border: 0, borderRadius: 0 }}>
            <summary>{t("settings.privacyRules")}<Icon name="chevron-down" /></summary>
            <div><p className="t-small">{t("settings.privacyText")}</p></div>
          </details>
          <Link className="group__row" to="/espace">
            <Icon name="users" />
            <span className="grow">{t("settings.duos")}</span>
            <span className="chev"><Icon name="arrow-right" size={20} /></span>
          </Link>
        </div>
      </section>

      <section className="section" aria-labelledby="set-intensity">
        <h2 className="t-section" id="set-intensity">{t("settings.intensity")}</h2>
        <div className="group">
          <fieldset className="group__pad">
            <legend className="sr-only">{t("settings.intensity")}</legend>
            <div className="chips" role="radiogroup" aria-label={t("settings.intensity")}>
              {INTENSITIES.map((i) => (
                <button key={i} type="button" className="chip" role="radio" aria-checked={profile.max_intensity === i}
                  onClick={() => profile.max_intensity !== i && void save({ max_intensity: i })}>{t(`filter.intensity.${i}`)}</button>
              ))}
            </div>
            <p className="t-meta">{t(`settings.intensityHint.${profile.max_intensity}`)}</p>
            <p className="t-meta">{t("settings.intensityDuo")}</p>
          </fieldset>
          <label className="group__pad field">
            <span className="field__label">{t("settings.country")}</span>
            <select className="input" value={profile.country ?? ""} onChange={(e) => void save({ country: e.target.value || null })}>
              <option value="">{t("settings.countryNone")}</option>
              {COUNTRIES.map((c) => <option key={c} value={c}>{t(`country.${c}`)}</option>)}
            </select>
            <span className="t-meta">{t("settings.countryHint")}</span>
          </label>
        </div>
      </section>

      <section className="section" aria-labelledby="set-reminders">
        <h2 className="t-section" id="set-reminders">{t("settings.reminders")}</h2>
        <div className="group">
          <label className="switch-row">
            <span className="switch-row__text"><span>{t("settings.remindersOn")}</span><span className="t-meta">{t("settings.remindersHint")}</span></span>
            <input className="switch" type="checkbox" role="switch" checked={rem.enabled} onChange={(e) => void save({ reminders: { ...rem, enabled: e.target.checked } })} />
          </label>
          {rem.enabled && (
            <div className="group__pad stack">
              <label className="field">
                <span className="field__label">{t("settings.remindersPerWeek")}</span>
                <select className="input" value={rem.per_week} onChange={(e) => void save({ reminders: { ...rem, per_week: Number(e.target.value) } })}>
                  {[1, 2, 3].map((n) => <option key={n} value={n}>{t("settings.remindersN", { n })}</option>)}
                </select>
              </label>
              <div className="row" style={{ gap: "var(--s-3)" }}>
                <label className="field grow">
                  <span className="field__label">{t("settings.quietStart")}</span>
                  <select className="input" value={rem.quiet_start} onChange={(e) => void save({ reminders: { ...rem, quiet_start: Number(e.target.value) } })}>
                    {hours.map((h) => <option key={h} value={h}>{t("settings.hour", { h })}</option>)}
                  </select>
                </label>
                <label className="field grow">
                  <span className="field__label">{t("settings.quietEnd")}</span>
                  <select className="input" value={rem.quiet_end} onChange={(e) => void save({ reminders: { ...rem, quiet_end: Number(e.target.value) } })}>
                    {hours.map((h) => <option key={h} value={h}>{t("settings.hour", { h })}</option>)}
                  </select>
                </label>
              </div>
              <Alert kind="info">{t("settings.remindersPending")}</Alert>
            </div>
          )}
        </div>
      </section>

      <section className="section">
        <h2 className="t-section">{t("settings.account")}</h2>
        <button className="btn btn--secondary" onClick={() => void signOut()}><Icon name="logout" />{t("settings.logout")}</button>
      </section>

      <section className="section" aria-labelledby="danger-title">
        <h2 className="t-section" id="danger-title" style={{ color: "var(--c-danger)" }}>{t("settings.danger")}</h2>
        <div className="card stack" style={{ borderColor: "var(--c-danger)" }}>
          <p className="t-small">{t("settings.deleteText")}</p>
          <button className="btn btn--danger" onClick={() => setConfirmDelete(true)}>{t("settings.delete")}</button>
        </div>
      </section>

      <section className="section">
        <h2 className="t-section">{t("settings.help")}</h2>
        <p className="t-meta">{t("settings.version", { v: __APP_VERSION__ })} · {t("app.credit")}</p>
      </section>

      {adultAsk && (
        <ConfirmDialog
          title={t("settings.adultTitle")}
          text={t("settings.adultText")}
          confirmLabel={t("settings.adultConfirm")}
          disabled={!adultCheck}
          onCancel={() => setAdultAsk(false)}
          onConfirm={() => {
            setAdultAsk(false);
            void save({ intimate_opt_in: true, adult_confirmed_at: new Date().toISOString() });
          }}
        >
          <label className="check-row">
            <input type="checkbox" checked={adultCheck} onChange={(e) => setAdultCheck(e.target.checked)} />
            <span>{t("settings.adultCheck")}</span>
          </label>
        </ConfirmDialog>
      )}

      {confirmDelete && (
        <ConfirmDialog
          title={t("settings.deleteTitle")}
          text={t("settings.deleteText")}
          confirmLabel={t("settings.deleteConfirm")}
          danger
          busy={deleting}
          disabled={typed.trim().toUpperCase() !== "SUPPRIMER"}
          onCancel={() => { setConfirmDelete(false); setTyped(""); }}
          onConfirm={() => void deleteAccount()}
        >
          <div className="field">
            <label className="field__label" htmlFor="del-confirm">{t("settings.deleteConfirmLabel")}</label>
            <input id="del-confirm" className="input" value={typed} onChange={(e) => setTyped(e.target.value)} autoComplete="off" />
          </div>
        </ConfirmDialog>
      )}
    </main>
  );
}

const OUT = 512; // taille de la photo enregistrée (carré)

/** Recadrage carré : déplacement au doigt/souris ou au clavier, zoom par curseur. */
function PhotoCropper({ file, onCancel, onSave }: { file: File; onCancel: () => void; onSave: (blob: Blob) => Promise<void> }) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [img, setImg] = useState<HTMLImageElement | null>(null);
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [busy, setBusy] = useState(false);
  const drag = useRef<{ x: number; y: number } | null>(null);
  const VIEW = 280;

  useEffect(() => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => setImg(image);
    image.src = url;
    return () => URL.revokeObjectURL(url);
  }, [file]);

  function draw(canvas: HTMLCanvasElement, size: number) {
    if (!img) return;
    const ctx = canvas.getContext("2d")!;
    const base = Math.max(size / img.width, size / img.height) * zoom;
    const w = img.width * base, h = img.height * base;
    ctx.fillStyle = "#FCE7DA";
    ctx.fillRect(0, 0, size, size);
    ctx.drawImage(img, (size - w) / 2 + offset.x * (size / VIEW), (size - h) / 2 + offset.y * (size / VIEW), w, h);
  }

  useEffect(() => {
    if (canvasRef.current) draw(canvasRef.current, VIEW);
  });

  function move(dx: number, dy: number) {
    setOffset((o) => ({ x: o.x + dx, y: o.y + dy }));
  }

  async function save() {
    setBusy(true);
    const out = document.createElement("canvas");
    out.width = OUT;
    out.height = OUT;
    draw(out, OUT);
    const blob = await new Promise<Blob | null>((r) => out.toBlob(r, "image/webp", 0.85));
    if (blob) await onSave(blob);
    setBusy(false);
  }

  return (
    <Sheet
      title={<h2 className="t-section">{t("profile.photo")}</h2>}
      onClose={onCancel}
      footer={
        <div className="sheet__foot">
          <button className="btn btn--secondary btn--auto" onClick={onCancel}>{t("common.cancel")}</button>
          <button className="btn" disabled={!img || busy} onClick={() => void save()}>{busy ? t("common.sending") : t("profile.photoSave")}</button>
        </div>
      }
    >
      <div className="center stack">
        <canvas
          ref={canvasRef}
          width={VIEW}
          height={VIEW}
          role="img"
          aria-label={t("profile.photoPreview")}
          tabIndex={0}
          style={{ width: VIEW, maxWidth: "100%", borderRadius: "50%", touchAction: "none", cursor: "grab", outlineOffset: 4 }}
          onPointerDown={(e: ReactPointerEvent) => { drag.current = { x: e.clientX, y: e.clientY }; (e.target as HTMLElement).setPointerCapture(e.pointerId); }}
          onPointerMove={(e: ReactPointerEvent) => {
            if (!drag.current) return;
            move(e.clientX - drag.current.x, e.clientY - drag.current.y);
            drag.current = { x: e.clientX, y: e.clientY };
          }}
          onPointerUp={() => { drag.current = null; }}
          onKeyDown={(e) => {
            const step = 8;
            if (e.key === "ArrowLeft") move(-step, 0);
            else if (e.key === "ArrowRight") move(step, 0);
            else if (e.key === "ArrowUp") move(0, -step);
            else if (e.key === "ArrowDown") move(0, step);
            else return;
            e.preventDefault();
          }}
        />
        <label className="field" style={{ width: "100%" }}>
          <span className="field__label">{t("profile.zoom")}</span>
          <input type="range" min={1} max={3} step={0.05} value={zoom} onChange={(e) => setZoom(Number(e.target.value))} />
        </label>
      </div>
    </Sheet>
  );
}

export function ProfileEdit() {
  const { profile, userId, session, updateProfile, refreshProfile } = useAuth();
  const toast = useToast();
  const [name, setName] = useState(profile?.display_name ?? "");
  const [form, setForm] = useState<WordForm>(profile?.word_form ?? "n");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const fileInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    setName(profile?.display_name ?? "");
    setForm(profile?.word_form ?? "n");
  }, [profile?.display_name, profile?.word_form]);

  if (!profile || !userId) return <PageLoading />;
  const dirty = name.trim() !== profile.display_name || form !== profile.word_form;

  async function save(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    const err = await updateProfile({ display_name: name.trim(), word_form: form });
    setBusy(false);
    setError(err ? t("profile.error") : null);
    if (!err) toast(t("profile.saved"));
  }

  function pick(f: File | undefined) {
    if (!f) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(f.type)) return setError(t("profile.photoType"));
    if (f.size > 10 * 1024 * 1024) return setError(t("profile.photoTooBig"));
    setError(null);
    setFile(f);
  }

  async function uploadPhoto(blob: Blob) {
    const path = `${userId}/${crypto.randomUUID()}.webp`;
    const { error: upErr } = await supabase.storage.from("avatars").upload(path, blob, { contentType: "image/webp", upsert: false });
    if (upErr) {
      setError(t("profile.photoError"));
      return;
    }
    const old = profile!.avatar_path;
    const err = await updateProfile({ avatar_path: path });
    if (err) {
      await supabase.storage.from("avatars").remove([path]);
      setError(t("profile.photoError"));
      return;
    }
    if (old) await supabase.storage.from("avatars").remove([old]);
    clearAvatarCache();
    await refreshProfile();
    setFile(null);
    toast(t("profile.photoSaved"));
  }

  async function removePhoto() {
    const old = profile!.avatar_path;
    const err = await updateProfile({ avatar_path: null });
    if (err) return setError(t("profile.photoError"));
    if (old) await supabase.storage.from("avatars").remove([old]);
    clearAvatarCache();
    toast(t("profile.photoRemoved"));
  }

  return (
    <SubPage backTo="/reglages" title={t("profile.title")}>
      <main className="page page--bare page--narrow">
        <section className="card stack stack--4">
          <h2 className="t-card">{t("profile.photo")}</h2>
          <div className="row">
            <Avatar name={profile.display_name} path={profile.avatar_path} size={80} me />
            <div className="stack stack--2 grow">
              <button className="btn btn--secondary btn--sm" onClick={() => fileInput.current?.click()}>
                <Icon name="image" size={20} />{profile.avatar_path ? t("profile.changePhoto") : t("profile.addPhoto")}
              </button>
              {profile.avatar_path && <button className="btn btn--quiet btn--sm" onClick={() => void removePhoto()}>{t("profile.removePhoto")}</button>}
            </div>
          </div>
          <p className="t-meta">{t("profile.photoHint")}</p>
          <input ref={fileInput} type="file" accept="image/jpeg,image/png,image/webp" className="sr-only" tabIndex={-1}
            onChange={(e) => { pick(e.target.files?.[0]); e.target.value = ""; }} />
        </section>

        <form className="card stack stack--4" onSubmit={save}>
          <div className="field">
            <label className="field__label" htmlFor="pf-name">{t("profile.name")}</label>
            <input id="pf-name" className="input" required maxLength={40} value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div className="field">
            <span className="field__label">{t("profile.email")}</span>
            <span className="t-small muted">{session?.user.email}</span>
          </div>
          <WordFormField value={form} onChange={setForm} />
          {error && <Alert>{error}</Alert>}
          <button className="btn" type="submit" disabled={busy || !dirty || !name.trim()}>{busy ? t("common.sending") : t("profile.save")}</button>
        </form>
        {file && <PhotoCropper file={file} onCancel={() => setFile(null)} onSave={uploadPhoto} />}
      </main>
    </SubPage>
  );
}
