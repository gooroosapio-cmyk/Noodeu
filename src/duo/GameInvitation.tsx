import { useEffect, useRef, useState } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { Alert, Icon, Sheet } from '../components/ui';
import { rpc } from '../lib/supabase';
import { useOnline } from '../lib/useOnline';
import { useDuo, type AppNotification } from './DuoProvider';
import { nextProposal, proposalKey } from './gameInvitation';

/** Les propositions attendent la sortie de partie ou de dialogue. Aucun changement de route sans Accepter. */
export function GameInvitation() {
  const duo = useDuo();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const online = useOnline();
  const dismissed = useRef(new Set<string>());
  const busyRef = useRef(false);
  const [busy, setBusy] = useState(false);
  const [current, setCurrent] = useState<AppNotification | null>(null);
  const [error, setError] = useState<string | null>(null);
  const path = useRef(pathname); path.current = pathname;

  useEffect(() => {
    if (current || pathname.startsWith('/partie/')) return;
    const check = () => {
      if (document.querySelector('[role="dialog"]')) return;
      const n = nextProposal(duo.notifications, duo.activeDuos.map(d => d.id), dismissed.current, Date.now());
      if (n) { setError(null); setCurrent(n); }
    };
    check();
    const observer = new MutationObserver(check);
    observer.observe(document.body, { childList: true, subtree: true });
    return () => observer.disconnect();
  }, [duo.notifications, duo.activeDuos, current, pathname]);

  function dismiss(n: AppNotification) {
    const key = proposalKey(n)!;
    dismissed.current.add(key);
    void duo.markNotificationsRead(duo.notifications.filter(x => proposalKey(x) === key).map(x => x.id));
    setCurrent(null);
  }
  async function accept(n: AppNotification) {
    if (busyRef.current || !online) return;
    busyRef.current = true; setBusy(true); setError(null);
    try {
      const res = await rpc<{ session?: { id: string; status: string; read_only?: boolean } }>('get_session_state', { p_session: n.data.session_id });
      if (path.current.startsWith('/partie/')) return;
      if (!res.ok) {
        setError(res.error === 'network' ? 'Connexion interrompue. Réessaie quand le réseau revient.' : 'Cette invitation n’est plus disponible. Tu peux la fermer.'); return;
      }
      if (!res.session || res.session.status !== 'lobby' || res.session.read_only) {
        setError('Ce salon n’attend plus de joueurs. Tu peux fermer cette invitation.'); return;
      }
      const target = duo.activeDuos.find(d => d.id === n.couple_id);
      if (!target) { setError('Ce duo n’est plus actif.'); return; }
      if (target.id !== duo.active?.id && !await duo.switchDuo(target.id)) {
        setError('Impossible de changer de duo. Réessaie.'); return;
      }
      // Le changement de duo peut prendre du temps : ne jamais quitter une partie ouverte entre-temps.
      if (path.current.startsWith('/partie/')) return;
      dismiss(n);
      navigate(`/partie/${res.session.id}`);
    } finally { busyRef.current = false; setBusy(false); }
  }
  if (!current || pathname.startsWith('/partie/')) return null;
  return <Sheet centered title={<h2 className="t-section">Une partie à deux ?</h2>} onClose={() => { if (!busyRef.current) dismiss(current); }}>
    <div className="invitation-summary">
      <Icon name="gamepad" size={32} />
      <div><p className="t-card">{String(current.data.name ?? 'Ton partenaire')} t’invite</p>
        <p>{String(current.data.title ?? 'Rejoindre le salon')}</p></div>
    </div>
    <p className="t-small muted">Accepte pour rejoindre le salon. La partie commence quand vous êtes prêts tous les deux.</p>
    {error && <Alert>{error}</Alert>}
    {!online && <Alert kind="info">Hors ligne : tu pourras accepter au retour du réseau.</Alert>}
    <div className="action-pair">
      <button className="btn btn--secondary" disabled={busy} onClick={() => dismiss(current)}>Refuser</button>
      <button className="btn" disabled={busy || !online} aria-busy={busy} onClick={() => void accept(current)}>Accepter</button>
    </div>
  </Sheet>;
}
