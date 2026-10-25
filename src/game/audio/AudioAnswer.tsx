import { useEffect, useRef, useState } from 'react';
import { Alert, Icon } from '../../components/ui';
import { rpc, supabase } from '../../lib/supabase';

const MAX_RECORD_MS = 29500; // Marge pour le padding codec ; le worker impose 30 000 ms décodées.
export function AudioAnswer({ sessionId, round, disabled, onSend, onBusy }: {
  sessionId: string; round: number; disabled: boolean;
  onSend: (p: Record<string, unknown>) => Promise<boolean>; onBusy: (busy: boolean) => void;
}) {
  const [enabled, setEnabled] = useState(false), [recording, setRecording] = useState(false);
  const [seconds, setSeconds] = useState(0), [url, setUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null), [sending, setSending] = useState(false);
  const recorder = useRef<MediaRecorder | null>(null), stream = useRef<MediaStream | null>(null);
  const blob = useRef<Blob | null>(null), objectUrl = useRef<string | null>(null), alive = useRef(true), lock = useRef(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null), tick = useRef<ReturnType<typeof setInterval> | null>(null);
  const upload = useRef<{id:string; path:string; expires_at:string; sent:boolean} | null>(null);
  function stop() { if (recorder.current?.state === 'recording') recorder.current.stop(); stream.current?.getTracks().forEach(t => t.stop()); }
  useEffect(() => {
    alive.current = true;
    void rpc<{enabled:boolean}>('get_audio_capability').then(r => { if (alive.current) setEnabled(r.ok && r.enabled === true); });
    const hide = () => { if (document.hidden) stop(); };
    document.addEventListener('visibilitychange', hide);
    return () => { alive.current = false; stop(); if (timer.current) clearTimeout(timer.current); if (tick.current) clearInterval(tick.current);
      if (objectUrl.current) URL.revokeObjectURL(objectUrl.current); document.removeEventListener('visibilitychange', hide); onBusy(false); };
  }, [onBusy]);
  async function start() {
    if (lock.current || disabled || !enabled) return;
    lock.current = true; onBusy(true); setError(null);
    try {
      if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') throw new Error('Ce navigateur ne permet pas l’enregistrement. Tu peux répondre par texte.');
      const mime = ['audio/webm;codecs=opus','audio/mp4','audio/ogg;codecs=opus'].find(m => MediaRecorder.isTypeSupported(m));
      if (!mime) throw new Error('Format audio indisponible. Tu peux répondre par texte.');
      const media = await navigator.mediaDevices.getUserMedia({audio:true});
      if (!alive.current || document.hidden) { media.getTracks().forEach(t=>t.stop()); lock.current=false; if(alive.current) onBusy(false); return; }
      stream.current = media; const chunks: Blob[] = [];
      const rec = new MediaRecorder(media,{mimeType:mime,audioBitsPerSecond:64000}); recorder.current = rec;
      rec.ondataavailable = e => { if (e.data.size) chunks.push(e.data); };
      rec.onstop = () => {
        if (timer.current) clearTimeout(timer.current); if (tick.current) clearInterval(tick.current);
        media.getTracks().forEach(t=>t.stop()); lock.current = false;
        if (!alive.current) return;
        setRecording(false); onBusy(false);
        const result = new Blob(chunks,{type:mime.split(';')[0]});
        if (!result.size || result.size > 1048576) { setError('Enregistrement invalide ou trop lourd. Réessaie ou écris ta réponse.'); return; }
        blob.current=result; upload.current=null;
        if (objectUrl.current) URL.revokeObjectURL(objectUrl.current);
        objectUrl.current=URL.createObjectURL(result); setUrl(objectUrl.current);
      };
      rec.onerror = () => { stop(); if (alive.current) setError('Enregistrement interrompu. Tu peux recommencer ou écrire.'); };
      setSeconds(0); setRecording(true); rec.start(250); const started=Date.now();
      tick.current=setInterval(()=>setSeconds(Math.min(30,Math.floor((Date.now()-started)/1000))),250);
      timer.current=setTimeout(stop,MAX_RECORD_MS);
    } catch { stop(); if(timer.current)clearTimeout(timer.current); if(tick.current)clearInterval(tick.current); stream.current=null; if (alive.current) { setRecording(false); setError('Micro indisponible ou permission refusée. Tu peux répondre par texte.'); onBusy(false); } lock.current=false; }
  }
  async function send(choice:'share'|'private') {
    if (lock.current || disabled || !blob.current) return;
    lock.current=true; setSending(true); onBusy(true); setError(null);
    try {
      if (!upload.current) {
        const id=crypto.randomUUID();
        const r=await rpc<{path:string;expires_at:string}>('reserve_answer_audio',{p_session:sessionId,p_round:round,p_id:id,p_mime:blob.current.type});
        if (!r.ok) throw new Error('L’audio n’est pas disponible pour cette carte. Tu peux répondre par texte.');
        upload.current={id,path:r.path,expires_at:r.expires_at,sent:false};
      }
      const u=upload.current;
      if (!u.sent) {
        const {error:e}=await supabase.storage.from('answer-audio').upload(u.path,blob.current,{contentType:blob.current.type,upsert:false,cacheControl:'0'});
        // Un envoi dont la réponse réseau a été perdue peut déjà exister : vérifier ensuite côté serveur.
        if (e && !['409','Duplicate'].includes(String(e.statusCode))) throw new Error('Envoi interrompu. Réessaie sans réenregistrer.');
        u.sent=true;
      }
      const ready=await rpc('get_answer_audio',{p_id:u.id});
      if (!ready.ok) throw new Error('Audio en cours de vérification. Réessaie dans un instant, ou choisis le texte.');
      if (alive.current) await onSend({choice,audio_id:u.id});
    } catch(e) { if(alive.current) setError(e instanceof Error ? e.message : 'Envoi impossible. Réessaie.'); }
    finally { lock.current=false; if(alive.current) {setSending(false);onBusy(false);} }
  }
  return <div className="audio-answer stack stack--2">
    <p className="t-small strong"><Icon name="mic" size={18} /> Ou une réponse audio</p>
    <p className="t-meta">30 secondes maximum. Privée avant la révélation, effacée après 24 h. Jamais ajoutée au coffre ni à la discussion.</p>
    {!enabled ? <p className="t-meta">L’audio n’est pas encore disponible. Tu peux écrire ta réponse.</p> : <>
      <button type="button" className="btn btn--secondary" disabled={sending || (disabled && !recording)} onClick={()=>recording?stop():void start()}>
        <Icon name={recording?'stop':'mic'} />{recording?`Arrêter · ${seconds}/30 s`:url?'Réenregistrer':'Enregistrer un audio'}
      </button>
      {url && !recording && <><audio controls src={url} preload="metadata" aria-label="Écouter mon brouillon audio" />
        <div className="action-pair"><button type="button" className="btn btn--secondary" disabled={sending || disabled} onClick={()=>void send('private')}>Valider pour moi</button>
          <button type="button" className="btn" disabled={sending || disabled} onClick={()=>void send('share')}>Valider et partager</button></div></>}
    </>}
    {error && <Alert>{error}</Alert>}
  </div>;
}

export function AudioPlayback({ id, expiresAt }: {id:string;expiresAt:string}) {
  const [url,setUrl]=useState<string|null>(null),[error,setError]=useState<string|null>(null),[busy,setBusy]=useState(false);
  const audio=useRef<HTMLAudioElement>(null),objectUrl=useRef<string|null>(null),alive=useRef(true);
  const expires=Date.parse(expiresAt);
  useEffect(()=>{
    alive.current=true; setUrl(null); setError(null);
    const cleanup=()=>{audio.current?.pause(); if(objectUrl.current)URL.revokeObjectURL(objectUrl.current);objectUrl.current=null;setUrl(null);};
    const timer=setTimeout(()=>{cleanup();setError('Cet audio a expiré.');},Math.max(0,expires-Date.now()));
    return()=>{alive.current=false;clearTimeout(timer);if(objectUrl.current)URL.revokeObjectURL(objectUrl.current);};
  },[id,expires]);
  async function load(){
    if(busy || Date.now()>=expires)return;
    setBusy(true);setError(null);
    const r=await rpc<{path:string}>('get_answer_audio',{p_id:id});
    if(r.ok){const {data}=await supabase.functions.invoke<Blob>('read-answer-audio',{body:{id}});
      if(alive.current && data && Date.now()<expires){objectUrl.current=URL.createObjectURL(data);setUrl(objectUrl.current);}
      else if(alive.current)setError('Audio expiré ou indisponible.');
    }else if(alive.current)setError('Audio expiré, privé ou indisponible.');
    if(alive.current)setBusy(false);
  }
  return <div className="stack stack--2">{url?<audio ref={audio} controls src={url} preload="none" aria-label="Réponse audio" />:
    <button className="btn btn--secondary" disabled={busy || Date.now()>=expires} onClick={()=>void load()}><Icon name="volume" />Écouter la réponse</button>}
    {error && <p className="t-meta" role="status">{error}</p>}</div>;
}
