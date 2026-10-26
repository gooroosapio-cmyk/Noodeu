import { useEffect, useRef, useState } from 'react';
import { Sheet } from '../../components/ui';

// Emplacements réservés : les octets Library n'ont pas encore pu être matérialisés.
// Aucun fichier fictif : absence/type incorrect/erreur => passage immédiat à la confirmation prêt.
const FILM = '/assets/original/launch/noodeu-launch-3s.mp4';
export function LaunchFilm({ sessionId, userId, title, onComplete }: {sessionId:string;userId:string;title:string;onComplete:()=>void}) {
  const [available,setAvailable]=useState(false);
  const video=useRef<HTMLVideoElement>(null),done=useRef(false),alive=useRef(true);
  const finishRef=useRef(onComplete);finishRef.current=onComplete;
  const key=`noodeu.launch-film.${userId}.${sessionId}`;
  const watchdog=useRef<ReturnType<typeof setTimeout>|null>(null);
  function finish(){if(done.current || !alive.current)return;done.current=true;try{sessionStorage.setItem(key,'1');}catch{/* stockage indisponible */}if(watchdog.current)clearTimeout(watchdog.current);video.current?.pause();finishRef.current();}
  const finishLatest=useRef(finish);finishLatest.current=finish;
  useEffect(()=>{
    alive.current=true;done.current=false;let active=true;const controller=new AbortController();
    const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches || document.documentElement.classList.contains('reduced-motion');
    let seen=false;try{seen=sessionStorage.getItem(key)==='1';}catch{/* restriction de stockage : garde locale de composant */}
    if(reduced || seen){finishLatest.current();return()=>{alive.current=false;};}
    // La partie reste au salon : aucune confirmation prêt n'est encore envoyée.
    watchdog.current=setTimeout(()=>{controller.abort();finishLatest.current();},1500);
    void fetch(FILM,{method:'HEAD',signal:controller.signal}).then(r=>{
      if(!active || !alive.current || done.current)return;
      if(!r.ok || !r.headers.get('content-type')?.startsWith('video/')){finishLatest.current();return;}
      if(watchdog.current)clearTimeout(watchdog.current);
      setAvailable(true);
      // Maximum de trois secondes d'overlay, même si le chargement bloque.
      watchdog.current=setTimeout(()=>finishLatest.current(),3000);
    }).catch(()=>{if(active)finishLatest.current();});
    return()=>{active=false;alive.current=false;controller.abort();if(watchdog.current)clearTimeout(watchdog.current);};
  },[key]);
  if(!available)return null;
  return <Sheet centered title={<h2 className="t-section">{title}</h2>} onClose={finish} closeLabel="Passer la vidéo">
    <video ref={video} className="launch-film" src={FILM} muted playsInline autoPlay preload="auto"
      aria-label="Introduction visuelle, sans son" onEnded={finish} onError={finish}
      onLoadedMetadata={()=>{const el=video.current;if(!el || !Number.isFinite(el.duration) || el.duration>3.05){finish();return;}void el.play().catch(finish);}} />
    <button className="btn btn--secondary" onClick={finish}>Passer et me déclarer prêt</button>
  </Sheet>;
}
