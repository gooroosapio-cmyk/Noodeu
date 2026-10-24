import { useState } from "react";
import { Link } from "react-router";
import { t } from "../i18n";
import { useOnline } from "../lib/useOnline";
import { Avatar } from "../components/Avatar";
import { Icon, Sheet, useToast } from "../components/ui";
import { useDuo } from "./DuoProvider";

/**
 * Bascule entre plusieurs duos actifs : le duo choisi devient le duo affiché partout (parties, discussion, question
 * du jour). Les autres duos restent intacts, avec leur historique ; le choix est gardé d'une connexion à l'autre.
 */
export function DuoSwitcher({ compact = false }: { compact?: boolean }) {
  const { active, activeDuos, switchDuo } = useDuo();
  const online = useOnline();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  if (!active) return null;
  const others = activeDuos.filter((d) => d.id !== active.id);
  const unreadElsewhere = others.reduce((n, d) => n + (d.unread ?? 0), 0);

  return (
    <>
      <button type="button" className={`btn btn--secondary btn--sm${compact ? " btn--auto" : ""}`} onClick={() => setOpen(true)} aria-haspopup="dialog">
        <Icon name="users" size={18} />
        {others.length ? t("duo.switch", { n: activeDuos.length }) : t("duo.addOther")}
        {unreadElsewhere > 0 && <span className="badge-count badge-count--inline" aria-label={t("duo.unreadElsewhere", { n: unreadElsewhere })}>{unreadElsewhere}</span>}
      </button>
      {open && (
        <Sheet title={<h2 className="t-section">{t("duo.switchTitle")}</h2>} onClose={() => setOpen(false)}>
          <p className="t-meta">{t("duo.switchHint")}</p>
          <ul className="list" aria-label={t("duo.switchTitle")}>
            {activeDuos.map((d) => {
              const current = d.id === active.id;
              return (
                <li key={d.id}>
                  <button type="button" className="list-row" aria-current={current || undefined} disabled={current || !online || busy !== null}
                    onClick={async () => {
                      setBusy(d.id);
                      const ok = await switchDuo(d.id);
                      setBusy(null);
                      if (ok) {
                        setOpen(false);
                        toast(t("duo.switched", { name: d.partner?.name || "?" }));
                      } else toast(t("profile.error"));
                    }}>
                    <Avatar name={d.partner?.name ?? "?"} path={d.partner?.avatar_path} size={40} />
                    <span className="list-row__body">
                      <span className="t-card">{d.partner?.deleted ? t("duo.deleted") : d.partner?.name}</span>
                      <span className="t-meta">{current ? t("duo.current") : busy === d.id ? t("common.sending") : t("duo.goTo")}</span>
                    </span>
                    {(d.unread ?? 0) > 0 && !current && <span className="badge-count badge-count--inline">{d.unread}</span>}
                    {current ? <Icon name="check" size={18} /> : <Icon name="arrow-right" size={18} />}
                  </button>
                </li>
              );
            })}
          </ul>
          <Link className="btn btn--quiet" to="/inviter" onClick={() => setOpen(false)}><Icon name="plus" size={18} />{t("duo.addOther")}</Link>
        </Sheet>
      )}
    </>
  );
}
