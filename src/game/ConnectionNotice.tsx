import {useEffect,useState} from 'react';
import {Icon} from '../components/ui';
export function ConnectionNotice({online,channel,networkError,onRetry}:{online:boolean;channel:string;networkError:boolean;onRetry:()=>void}){
 const [delayed,setDelayed]=useState(false);
 useEffect(()=>{setDelayed(false);if(channel==='live')return;const timer=setTimeout(()=>setDelayed(true),5000);return()=>clearTimeout(timer);},[channel]);
 if(online && !networkError && !delayed)return null;
 return <div className="connection-notice" role="status">
  <Icon name={!online?'wifi-off':'refresh'} size={18}/>
  <div className="grow"><p className="t-small strong">{!online?'En attente du réseau':networkError?'Connexion interrompue':'Actualisation automatique'}</p>
   <p className="t-meta">{!online?'La partie reste affichée. Reconnecte-toi pour envoyer.':networkError?'La dernière version reste affichée. Tu peux réessayer.':'Le direct revient doucement. La partie est relue régulièrement.'}</p></div>
  {online && networkError && <button className="btn btn--secondary btn--auto" onClick={onRetry}>Réessayer</button>}
 </div>;
}
