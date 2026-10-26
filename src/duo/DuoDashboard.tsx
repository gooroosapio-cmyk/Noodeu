import { useCallback, useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react';
import { Alert, Icon, Loading, Sheet, useToast } from '../components/ui';
import { rpc, supabase } from '../lib/supabase';
import { onResume, useOnline } from '../lib/useOnline';
import { useDuo } from './DuoProvider';
import { prepareCover } from './cover';

type Note = { id: string; body: string; due_on: string | null; done: boolean; version: number };
type Space = { cover_path: string | null; version: number; notes: Note[] };

/** Espace partagé d'un duo (couverture et notes) : mêmes RPC versionnées qu'avant, découpées pour les écrans V7.
 *  Remonter le composant par duo (key=coupleId) : aucun brouillon, objet ou réponse tardive ne traverse les duos. */
export function useDuoSpace(coupleId: string, active: boolean) {
  const { duos } = useDuo();
  const [space, setSpace] = useState<Space | null>(null);
  const [unavailable, setUnavailable] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const refreshGeneration = useRef(0);
  const busyRef = useRef(false), alive = useRef(true);
  const online = useOnline(), toast = useToast();
  useEffect(() => { alive.current = true; return () => { alive.current = false; }; }, []);
  const refresh = useCallback(async () => {
    const generation = ++refreshGeneration.current;
    const res = await rpc<Space>('get_duo_space', { p_couple: coupleId });
    if (!alive.current || generation !== refreshGeneration.current) return;
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
      if (!alive.current) return;
      const path = `${coupleId}/${crypto.randomUUID()}.webp`;
      const { error: storageError } = await supabase.storage.from('duo-covers').upload(path, blob, { contentType: 'image/webp', upsert: false, cacheControl: '0' });
      if (storageError) throw new Error('La photo n’a pas été enregistrée. Réessaie.');
      if (!alive.current) return;
      const res = await rpc('set_duo_cover', { p_couple: coupleId, p_path: path, p_version: space.version });
      if (!res.ok) throw new Error(res.error === 'conflict' ? 'La couverture a changé entre-temps. Recharge puis réessaie.' : 'Impossible de mettre à jour la couverture.');
      if (alive.current) { await refresh(); toast('Couverture partagée avec ton duo.'); }
    } catch (e) { if (alive.current) setError(e instanceof Error ? e.message : 'Impossible de lire cette photo.'); }
    finally { busyRef.current = false; if (alive.current) setBusy(false); }
  }
  async function save(note: Note) {
    if (busyRef.current || !active || !online) return false;
    busyRef.current = true; setBusy(true); setError(null);
    try {
      const res = await rpc('save_duo_note', { p_couple: coupleId, p_id: note.id, p_body: note.body, p_due: note.due_on, p_done: note.done, p_version: note.version });
      if (!alive.current) return false;
      if (!res.ok) { setError(res.error === 'conflict' ? 'Cette note a changé. Recharge avant de réessayer.' : 'La note n’a pas été enregistrée. Réessaie.'); await refresh(); return false; }
      await refresh();
      return true;
    } finally { busyRef.current = false; if (alive.current) setBusy(false); }
  }
  return { space, unavailable, error, url, busy, online, refresh, upload, save, busyRef };
}

/** Carte de couverture du témoin 04 : photo 128 px, identité du duo, crayon pour changer la photo. */
export function DuoSpaceCard({ space: s, active, avatars, title, subtitle }: { space: ReturnType<typeof useDuoSpace>; active: boolean; avatars: ReactNode; title: string; subtitle: string }) {
  const fileInput = useRef<HTMLInputElement>(null);
  return (
    <section className="v7-space-card" aria-label={title}>
      <img className="v7-space-card__cover" src={s.url ?? '/assets/noodeu/v7/duo-living-room.webp'} alt="" width={1280} height={430} />
      <div className="v7-space-card__row">
        {avatars}
        <span className="v7-duo-card__text"><strong>{title}</strong><small>{subtitle}</small></span>
        {active && <button type="button" className="icon-btn" aria-label="Changer la photo de couverture" disabled={!s.space || s.busy || !s.online} onClick={() => fileInput.current?.click()}><Icon name="pencil" size={20} /></button>}
      </div>
      <input ref={fileInput} type="file" className="sr-only" tabIndex={-1} accept="image/jpeg,image/png,image/webp" onChange={e => { const f = e.target.files?.[0]; e.target.value = ''; if (f) void s.upload(f); }} />
      {s.error && <div className="v7-space-card__alert"><Alert>{s.error}</Alert></div>}
    </section>
  );
}

/** Notes partagées du duo (onglet « Nos notes » du coffre). */
export function DuoNotes({ coupleId, active, partner }: { coupleId: string; active: boolean; partner: string }) {
  const s = useDuoSpace(coupleId, active);
  const [edit, setEdit] = useState(false);
  const [body, setBody] = useState('');
  const [due, setDue] = useState('');
  const noteId = useRef(crypto.randomUUID());
  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (await s.save({ id: noteId.current, body: body.trim(), due_on: due || null, done: false, version: 0 })) {
      setEdit(false); setBody(''); setDue(''); noteId.current = crypto.randomUUID();
    }
  };
  return (
    <section className="stack stack--3" aria-label="Nos notes">
      <div className="v7-section-head"><h2>Notes partagées</h2>
        {active && <button className="v7-link" type="button" disabled={!s.space || s.busy || !s.online} onClick={() => setEdit(true)}><Icon name="plus" size={18} />Ajouter</button>}</div>
      {s.error && !edit && <Alert>{s.error}</Alert>}
      {s.unavailable ? <Alert kind="info">Les notes ne sont pas disponibles pour le moment. <button className="btn btn--quiet" onClick={() => void s.refresh()}>Réessayer</button></Alert> : !s.space ? <Loading /> : !s.space.notes.length ? <p className="t-small muted">Aucune note pour le moment.</p> :
        <ul className="duo-notes">{s.space.notes.map(note => <li key={note.id}>
          <label className={`choice${note.done ? ' is-done' : ''}`}><input type="checkbox" checked={note.done} disabled={!active || s.busy || !s.online} onChange={() => void s.save({ ...note, done: !note.done })} />
            <span className="choice__text"><span>{note.body}</span>{note.due_on && <time className="t-meta" dateTime={note.due_on}>{new Date(`${note.due_on}T12:00:00`).toLocaleDateString('fr-FR')}</time>}</span></label>
        </li>)}</ul>}
      {edit && <Sheet title={<h2 className="t-section">Une note pour vous deux</h2>} onClose={() => { if (!s.busyRef.current) setEdit(false); }}>
        <form className="stack stack--4" onSubmit={submit}>
          <label className="field">Votre note<textarea className="input" rows={3} maxLength={600} required value={body} onChange={e => setBody(e.target.value)} /></label>
          <label className="field">Date facultative<input className="input" type="date" value={due} onChange={e => setDue(e.target.value)} /></label>
          <p className="t-small muted">Visible et modifiable par toi et {partner}. Aucun rappel automatique.</p>
          {s.error && <Alert>{s.error}</Alert>}
          <button className="btn" disabled={s.busy || !s.online || !body.trim()} aria-busy={s.busy}>Enregistrer la note</button>
        </form>
      </Sheet>}
    </section>
  );
}
