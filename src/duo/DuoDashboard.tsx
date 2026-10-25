import { useCallback, useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { Alert, Icon, Loading, Sheet, useToast } from '../components/ui';
import { rpc, supabase } from '../lib/supabase';
import { onResume, useOnline } from '../lib/useOnline';
import { useDuo } from './DuoProvider';
import { prepareCover } from './cover';

type Note = { id: string; body: string; due_on: string | null; done: boolean; version: number };
type Space = { cover_path: string | null; version: number; notes: Note[] };

/** Remonté par duo (key=coupleId) : aucun brouillon, objet ou réponse tardive ne traverse les duos. */
export function DuoDashboard({ coupleId, active, partner, children }: { coupleId: string; active: boolean; partner: string; children?: ReactNode }) {
  const { duos } = useDuo();
  const [space, setSpace] = useState<Space | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [edit, setEdit] = useState(false);
  const [body, setBody] = useState('');
  const [due, setDue] = useState('');
  const [busy, setBusy] = useState(false);
  const busyRef = useRef(false), alive = useRef(true), noteId = useRef(crypto.randomUUID());
  const fileInput = useRef<HTMLInputElement>(null);
  const online = useOnline(), toast = useToast();
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  const refresh = useCallback(async () => {
    const res = await rpc<Space>('get_duo_space', { p_couple: coupleId });
    if (!alive.current) return;
    if (res.ok && Array.isArray(res.notes)) { setSpace(res); setUnavailable(false); }
    else setUnavailable(true);
  }, [coupleId]);
  useEffect(() => {
    void refresh();
    const resume = onResume(() => void refresh());
    return resume;
  }, [coupleId, refresh, duos]);
  useEffect(() => {
    let cancelled = false; let objectUrl: string | null = null;
    setUrl(null);
    if (space?.cover_path) void supabase.storage.from('duo-covers').download(space.cover_path).then(({ data }) => {
      if (!cancelled && data) { objectUrl = URL.createObjectURL(data); setUrl(objectUrl); }
    });
    return () => { cancelled = true; if (objectUrl) URL.revokeObjectURL(objectUrl); };
  }, [space?.cover_path]);
  async function upload(file: File) {
    if (busyRef.current || !space || !active || !online) return;
    busyRef.current = true; setBusy(true); setError(null);
    try {
      const blob = await prepareCover(file);
      const path = `${coupleId}/${crypto.randomUUID()}.webp`;
      const { error: storageError } = await supabase.storage.from('duo-covers').upload(path, blob, { contentType: 'image/webp', upsert: false, cacheControl: '0' });
      if (storageError) throw new Error('La photo n’a pas été enregistrée. Réessaie.');
      const res = await rpc('set_duo_cover', { p_couple: coupleId, p_path: path, p_version: space.version });
      if (!res.ok) throw new Error(res.error === 'conflict' ? 'La couverture a changé entre-temps. Recharge puis réessaie.' : 'Impossible de mettre à jour la couverture.');
      if (alive.current) { await refresh(); toast('Couverture partagée avec ton duo.'); }
    } catch (e) { if (alive.current) setError(e instanceof Error ? e.message : 'Impossible de lire cette photo.'); }
    finally { busyRef.current = false; if (alive.current) setBusy(false); }
  }
  async function save(note: Note) {
    if (busyRef.current || !active || !online) return;
    busyRef.current = true; setBusy(true); setError(null);
    try {
      const res = await rpc('save_duo_note', { p_couple: coupleId, p_id: note.id, p_body: note.body, p_due: note.due_on, p_done: note.done, p_version: note.version });
      if (!alive.current) return;
      if (!res.ok) { setError(res.error === 'conflict' ? 'Cette note a changé. Recharge avant de réessayer.' : 'La note n’a pas été enregistrée. Réessaie.'); await refresh(); return; }
      setEdit(false); setBody(''); setDue(''); noteId.current = crypto.randomUUID(); await refresh();
    } finally { busyRef.current = false; if (alive.current) setBusy(false); }
  }
  const submit = (e: FormEvent) => { e.preventDefault(); void save({ id: noteId.current, body: body.trim(), due_on: due || null, done: false, version: 0 }); };
  return <section className="duo-dashboard" aria-label={`Votre espace avec ${partner}`}>
    <div className="duo-cover">
      <img src={url ?? '/assets/original/duo-cover.webp'} alt="" width={1400} height={560} />
      <div className="duo-cover__caption"><span className="t-meta">VOTRE ESPACE À DEUX</span><h2 className="t-section">Des moments à garder</h2></div>
    </div>
    <div className="duo-dashboard__body stack stack--4">
      <div className="row"><span className="t-small grow"><Icon name="lock" size={16} /> Seulement toi et {partner}</span>
        {active && <button className="icon-btn" aria-label="Changer la photo de couverture" disabled={!space || busy || !online} onClick={() => fileInput.current?.click()}><Icon name="image" /></button>}</div>
      <input ref={fileInput} type="file" className="sr-only" tabIndex={-1} accept="image/jpeg,image/png,image/webp" onChange={e => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void upload(f); }} />
      {error && <Alert>{error}</Alert>}
      {children}
      <div className="section__head"><h3 className="t-card">Nos petites notes</h3>
        {active && <button className="btn btn--soft btn--auto" disabled={!space || busy || !online} onClick={() => setEdit(true)}><Icon name="plus" size={18} />Ajouter</button>}</div>
      <p className="t-meta">Des idées et rappels partagés, sans notification programmée.</p>
      {unavailable ? <Alert kind="info">Les notes et la photo personnelle ne sont pas disponibles pour le moment. <button className="btn btn--quiet" onClick={() => void refresh()}>Réessayer</button></Alert> : !space ? <Loading /> : !space.notes.length ? <p className="t-small muted">Un rendez-vous à prévoir, une envie à partager… Votre première note trouvera sa place ici.</p> :
        <ul className="duo-notes">{space.notes.map(note => <li key={note.id}>
          <label className={`choice${note.done ? ' is-done' : ''}`}><input type="checkbox" checked={note.done} disabled={!active || busy || !online} onChange={() => void save({...note, done: !note.done})} />
            <span className="choice__text"><span>{note.body}</span>{note.due_on && <time className="t-meta" dateTime={note.due_on}>{new Date(`${note.due_on}T12:00:00`).toLocaleDateString('fr-FR')}</time>}</span></label>
        </li>)}</ul>}
    </div>
    {edit && <Sheet title={<h2 className="t-section">Une note pour vous deux</h2>} onClose={() => { if (!busyRef.current) setEdit(false); }}>
      <form className="stack stack--4" onSubmit={submit}>
        <label className="field">Votre note<textarea className="input" rows={3} maxLength={600} required value={body} onChange={e => setBody(e.target.value)} /></label>
        <label className="field">Date facultative<input className="input" type="date" value={due} onChange={e => setDue(e.target.value)} /></label>
        <p className="t-small muted">Visible et modifiable par toi et {partner}. Aucun rappel automatique.</p>
        {error && <Alert>{error}</Alert>}
        <button className="btn" disabled={busy || !online || !body.trim()} aria-busy={busy}>Enregistrer la note</button>
      </form>
    </Sheet>}
  </section>;
}
