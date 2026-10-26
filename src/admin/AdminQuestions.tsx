// Administration des questions : filtres catégorie / sous-catégorie, recherche, tri, modification, ajout,
// suppression et bascule +18. Chaque action est vérifiée par le serveur (comptes administrateurs uniquement).
import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import { t } from "../i18n";
import { rpc } from "../lib/supabase";
import { SubPage } from "../components/AppShell";
import { Alert, ConfirmDialog, Icon, PageLoading, useToast } from "../components/ui";

export interface AdminQuestion {
  bank: string; idx: number; id: string; text: string; theme?: string; adult: boolean;
  options?: { id: string; text: string }[]; kind?: "truth" | "dare";
  category: string; activity: string; type: "pack" | "test" | "game"; mechanic: string; archived?: boolean; admin?: boolean;
}
type Sort = "order" | "az" | "adult" | "recent";
const PAGE = 40;

/** Pour une sous-catégorie : ce que le formulaire demande en plus du texte. */
const needsOptions = (m: string) => m === "nd_dilemma";
const needsKind = (m: string) => m === "nd_truth_dare";

function errorOf(code?: string) {
  const known = ["invalid_text", "invalid_options", "invalid_kind", "locked_test", "last_question", "not_found", "forbidden", "network"];
  return code && known.includes(code) ? t(`admin.err.${code}` as never) : t("admin.err.unexpected");
}

function QuestionForm({ mechanic, initial, busy, onSubmit, onCancel, submitLabel }: {
  mechanic: string; initial?: Partial<AdminQuestion>; busy: boolean; submitLabel: string;
  onSubmit: (v: { text: string; options?: string[]; kind?: string; adult: boolean }) => void; onCancel: () => void;
}) {
  const [text, setText] = useState(initial?.text ?? "");
  const [a, setA] = useState(initial?.options?.[0]?.text ?? "");
  const [b, setB] = useState(initial?.options?.[1]?.text ?? "");
  const [kind, setKind] = useState<string>(initial?.kind ?? "");
  const [adult, setAdult] = useState(Boolean(initial?.adult));
  const ok = text.trim() && (!needsOptions(mechanic) || (a.trim() && b.trim())) && (!needsKind(mechanic) || kind);
  function submit(e: FormEvent) {
    e.preventDefault();
    if (busy || !ok) return;
    onSubmit({ text: text.trim(), adult, ...(needsOptions(mechanic) ? { options: [a.trim(), b.trim()] } : {}), ...(needsKind(mechanic) ? { kind } : {}) });
  }
  return (
    <form className="admin-form stack stack--3" onSubmit={submit}>
      {needsKind(mechanic) && (
        <div className="chips" role="radiogroup" aria-label={t("admin.kind")}>
          {(["truth", "dare"] as const).map((k) => (
            <button key={k} type="button" role="radio" className="chip" aria-checked={kind === k} aria-pressed={kind === k} onClick={() => setKind(k)}>
              {t(k === "truth" ? "conv.td.truth" : "conv.td.dare")}
            </button>
          ))}
        </div>
      )}
      <label className="field">
        <span className="field__label">{t("admin.text")}</span>
        <textarea className="input q-textarea" maxLength={600} value={text} onChange={(e) => setText(e.target.value)} autoFocus />
        {mechanic === "nd_sentence" && <span className="field__hint">{t("admin.sentenceHint")}</span>}
      </label>
      {needsOptions(mechanic) && (
        <div className="admin-form__pair">
          <label className="field"><span className="field__label">{t("admin.optionA")}</span>
            <input className="input" maxLength={200} value={a} onChange={(e) => setA(e.target.value)} /></label>
          <label className="field"><span className="field__label">{t("admin.optionB")}</span>
            <input className="input" maxLength={200} value={b} onChange={(e) => setB(e.target.value)} /></label>
        </div>
      )}
      <label className="switch-row">
        <span className="switch-row__text"><span>{t("admin.adultLabel")}</span><span className="t-meta">{t("admin.adultHint")}</span></span>
        <input className="switch" type="checkbox" role="switch" checked={adult} onChange={(e) => setAdult(e.target.checked)} />
      </label>
      <div className="row row--wrap">
        <button className="btn btn--auto" type="submit" disabled={busy || !ok}><Icon name="check" size={18} />{busy ? t("common.sending") : submitLabel}</button>
        <button className="btn btn--secondary btn--auto" type="button" onClick={onCancel} disabled={busy}>{t("common.cancel")}</button>
      </div>
    </form>
  );
}

function QuestionRow({ q, onChanged, showActivity }: { q: AdminQuestion; onChanged: (patch: Partial<AdminQuestion> | null) => void; showActivity: boolean }) {
  const toast = useToast();
  const [editing, setEditing] = useState(false);
  const [confirmDel, setConfirmDel] = useState(false);
  const [busy, setBusy] = useState(false);
  const busyRef = useRef(false);
  const [error, setError] = useState<string | null>(null);
  const locked = q.type === "test";

  async function toggleAdult() {
    if (busyRef.current) return;
    busyRef.current = true;
    setBusy(true);
    try {
      const r = await rpc("admin_set_question_adult", { p_bank: q.bank, p_id: q.id, p_adult: !q.adult });
      if (r.ok) { onChanged({ adult: !q.adult }); toast(!q.adult ? t("admin.markedAdult") : t("admin.markedAll")); }
      else setError(errorOf(r.error));
    } finally { busyRef.current = false; setBusy(false); }
  }
  async function save(v: { text: string; options?: string[]; kind?: string; adult: boolean }) {
    if (busyRef.current) return;
    busyRef.current = true;
    setBusy(true);
    try {
      setError(null);
      const r = await rpc("admin_update_question", { p_bank: q.bank, p_id: q.id, p_text: v.text, p_options: v.options ?? null, p_kind: v.kind ?? null, p_adult: v.adult });
      if (!r.ok) return setError(errorOf(r.error));
      onChanged({ text: v.text.replace(/\s+/g, " "), adult: v.adult, ...(v.kind ? { kind: v.kind as AdminQuestion["kind"] } : {}),
        ...(v.options && q.options ? { options: q.options.map((o, i) => ({ ...o, text: v.options![i] })) } : {}) });
      setEditing(false);
      toast(t("common.saved"));
    } finally { busyRef.current = false; setBusy(false); }
  }
  async function remove() {
    if (busyRef.current) return;
    busyRef.current = true;
    setBusy(true);
    try {
      const r = await rpc("admin_delete_question", { p_bank: q.bank, p_id: q.id });
      setConfirmDel(false);
      if (r.ok) { onChanged(null); toast(t("admin.deleted")); } else setError(errorOf(r.error));
    } finally { busyRef.current = false; setBusy(false); }
  }

  return (
    <li className={`admin-q${q.adult ? " admin-q--adult" : ""}`}>
      <div className="admin-q__meta">
        {showActivity && <span className="t-meta strong">{q.activity}</span>}
        {q.kind && <span className="nd-chip">{t(q.kind === "truth" ? "conv.td.truth" : "conv.td.dare")}</span>}
        {q.theme && q.theme !== q.activity && <span className="t-meta">{q.theme}</span>}
        {q.admin && <span className="nd-chip nd-chip--mint">{t("admin.added")}</span>}
        {q.archived && <span className="nd-chip">{t("admin.archived")}</span>}
      </div>
      {editing ? (
        <QuestionForm mechanic={q.mechanic} initial={q} busy={busy} submitLabel={t("admin.save")} onSubmit={(v) => void save(v)} onCancel={() => setEditing(false)} />
      ) : (
        <>
          <p className="admin-q__text">{q.text}</p>
          {q.options && <p className="t-meta">{q.options.map((o) => o.text).join(" · ")}</p>}
          <div className="admin-q__actions">
            <button type="button" className={`adult-toggle${q.adult ? " is-on" : ""}`} aria-pressed={q.adult} disabled={busy} onClick={() => void toggleAdult()}
              aria-label={q.adult ? t("admin.adultOnLabel") : t("admin.adultOffLabel")}>
              {q.adult ? "+18" : t("admin.allPublic")}
            </button>
            <button type="button" className="btn btn--quiet btn--sm btn--auto" disabled={busy} onClick={() => setEditing(true)}><Icon name="pencil" size={16} />{t("admin.edit")}</button>
            {!locked && (
              <button type="button" className="btn btn--quiet btn--sm btn--auto admin-q__del" disabled={busy} onClick={() => setConfirmDel(true)}><Icon name="delete" size={16} />{t("admin.delete")}</button>
            )}
          </div>
        </>
      )}
      {error && <Alert>{error}</Alert>}
      {confirmDel && (
        <ConfirmDialog title={t("admin.deleteTitle")} text={<><p>{t("admin.deleteText")}</p><p className="strong">« {q.text} »</p></>}
          confirmLabel={t("admin.delete")} danger busy={busy} onCancel={() => setConfirmDel(false)} onConfirm={() => void remove()} />
      )}
    </li>
  );
}

export function AdminQuestions() {
  const toast = useToast();
  const [all, setAll] = useState<AdminQuestion[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [cat, setCat] = useState("");
  const [sub, setSub] = useState("");
  const [adult, setAdult] = useState<"all" | "yes" | "no">("all");
  const [search, setSearch] = useState("");
  const [sort, setSort] = useState<Sort>("order");
  const [limit, setLimit] = useState(PAGE);
  const [adding, setAdding] = useState(false);
  const [busy, setBusy] = useState(false);
  const busyRef = useRef(false);

  async function load() {
    const r = await rpc<{ questions: AdminQuestion[] }>("admin_list_questions");
    if (r.ok) setAll(r.questions);
    else setError(errorOf(r.error));
  }
  useEffect(() => { void load(); }, []);
  useEffect(() => setLimit(PAGE), [cat, sub, adult, search, sort]);

  const categories = useMemo(() => [...new Set((all ?? []).map((q) => q.category))], [all]);
  const subs = useMemo(() => [...new Set((all ?? []).filter((q) => !cat || q.category === cat).map((q) => q.activity))], [all, cat]);
  const subQ = useMemo(() => (all ?? []).find((q) => q.activity === sub), [all, sub]);
  const list = useMemo(() => {
    const needle = search.trim().toLowerCase();
    const out = (all ?? []).filter((q) => (!cat || q.category === cat) && (!sub || q.activity === sub)
      && (adult === "all" || (adult === "yes") === q.adult)
      && (!needle || q.text.toLowerCase().includes(needle) || (q.theme ?? "").toLowerCase().includes(needle)));
    if (sort === "az") return [...out].sort((a, b) => a.text.localeCompare(b.text, "fr"));
    if (sort === "adult") return [...out].sort((a, b) => Number(b.adult) - Number(a.adult));
    if (sort === "recent") return [...out].sort((a, b) => Number(Boolean(b.admin)) - Number(Boolean(a.admin)) || b.idx - a.idx);
    return out;
  }, [all, cat, sub, adult, search, sort]);

  function patch(q: AdminQuestion, p: Partial<AdminQuestion> | null) {
    setAll((xs) => (xs ?? []).flatMap((x) => (x.bank === q.bank && x.id === q.id ? (p ? [{ ...x, ...p }] : []) : [x])));
  }
  async function add(v: { text: string; options?: string[]; kind?: string; adult: boolean }) {
    if (!subQ || busyRef.current) return;
    busyRef.current = true;
    setBusy(true);
    try {
      const r = await rpc("admin_add_question", { p_bank: subQ.bank, p_text: v.text, p_adult: v.adult, p_options: v.options ?? null, p_kind: v.kind ?? null });
      if (!r.ok) return toast(errorOf(r.error));
      setAdding(false);
      toast(t("admin.addedToast"));
      setSort("recent");
      await load();
    } finally { busyRef.current = false; setBusy(false); }
  }

  if (error) return <SubPage backTo="/reglages" title={t("admin.title")}><main className="page page--bare"><Alert>{error}</Alert></main></SubPage>;
  if (!all) return <PageLoading />;
  const canAdd = Boolean(subQ) && subQ!.type !== "test";

  return (
    <SubPage backTo="/reglages" title={t("admin.title")}>
      <main className="page page--bare admin">
        <div className="admin-filters card">
          <label className="field">
            <span className="field__label">{t("admin.category")}</span>
            <select className="input" value={cat} onChange={(e) => { setCat(e.target.value); setSub(""); setAdding(false); }}>
              <option value="">{t("admin.allCategories")}</option>
              {categories.map((c) => <option key={c} value={c}>{c}</option>)}
            </select>
          </label>
          <label className="field">
            <span className="field__label">{t("admin.subcategory")}</span>
            <select className="input" value={sub} onChange={(e) => { setSub(e.target.value); setAdding(false); }}>
              <option value="">{t("admin.allSubcategories")}</option>
              {subs.map((s) => <option key={s} value={s}>{s}</option>)}
            </select>
          </label>
          <label className="field admin-filters__wide">
            <span className="field__label">{t("admin.search")}</span>
            <input className="input" type="search" value={search} onChange={(e) => setSearch(e.target.value)} placeholder={t("admin.searchPlaceholder")} />
          </label>
          <label className="field">
            <span className="field__label">{t("admin.adultFilter")}</span>
            <select className="input" value={adult} onChange={(e) => setAdult(e.target.value as typeof adult)}>
              <option value="all">{t("admin.adultAll")}</option>
              <option value="yes">{t("admin.adultYes")}</option>
              <option value="no">{t("admin.adultNo")}</option>
            </select>
          </label>
          <label className="field">
            <span className="field__label">{t("admin.sort")}</span>
            <select className="input" value={sort} onChange={(e) => setSort(e.target.value as Sort)}>
              <option value="order">{t("admin.sortOrder")}</option>
              <option value="az">{t("admin.sortAz")}</option>
              <option value="adult">{t("admin.sortAdult")}</option>
              <option value="recent">{t("admin.sortRecent")}</option>
            </select>
          </label>
        </div>

        <div className="admin-bar">
          <p className="t-small strong" aria-live="polite">{t("admin.count", { n: list.length })}</p>
          <button className="btn btn--auto btn--sm" disabled={!canAdd || adding} onClick={() => setAdding(true)}><Icon name="plus" size={18} />{t("admin.add")}</button>
        </div>
        {!sub && <p className="t-meta">{t("admin.addHint")}</p>}
        {subQ?.type === "test" && <Alert kind="info">{t("admin.testLocked")}</Alert>}
        {adding && subQ && (
          <section className="card stack stack--2">
            <h2 className="t-section">{t("admin.addTitle", { name: subQ.activity })}</h2>
            <QuestionForm mechanic={subQ.mechanic} busy={busy} submitLabel={t("admin.add")} onSubmit={(v) => void add(v)} onCancel={() => setAdding(false)} />
          </section>
        )}

        <ul className="admin-list">
          {list.slice(0, limit).map((q) => <QuestionRow key={`${q.bank}:${q.id}`} q={q} showActivity={!sub} onChanged={(p) => patch(q, p)} />)}
        </ul>
        {list.length === 0 && <p className="muted center">{t("admin.empty")}</p>}
        {list.length > limit && <button className="btn btn--secondary" onClick={() => setLimit(limit + PAGE)}>{t("admin.more", { n: list.length - limit })}</button>}
      </main>
    </SubPage>
  );
}
