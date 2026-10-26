import { Link } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { Avatar } from "../components/Avatar";
import { Icon } from "../components/ui";
import type { DuoSummary } from "./DuoProvider";

/**
 * Identité du duo : vraie photo de l'utilisateur, puis vraie photo de l'autre membre
 * ou un vrai bouton « + » qui ouvre l'invitation. Jamais une image décorative.
 */
export function DuoIdentity({ duo, online = false, size = 52, showStatus = true, center = false }: { duo: DuoSummary | null; online?: boolean; size?: number; showStatus?: boolean; center?: boolean }) {
  const { profile } = useAuth();
  const me = profile?.display_name ?? "";
  const partner = duo?.partner;
  return (
    <div className={center ? "duo-id duo-id--center" : "duo-id"}>
      <div className="duo-id__pair">
        <Avatar name={me} path={profile?.avatar_path} size={size} me />
        {partner ? (
          <Avatar name={partner.name || "?"} path={partner.avatar_path} size={size} />
        ) : (
          <Link className="duo-id__add" to="/inviter" aria-label={t("duo.invite")} style={{ width: size, height: size }}>
            <Icon name="plus" />
          </Link>
        )}
      </div>
      <div className="duo-id__names">
        <span className="t-card">{partner ? `${me} & ${partner.deleted ? t("duo.deleted") : partner.name}` : me}</span>
        {showStatus && partner && duo?.active && online && (
          <span className="status"><span className="status-dot" aria-hidden="true" />{t("duo.online")}</span>
        )}
        {showStatus && duo && !duo.active && <span className="tag tag--archived" style={{ justifySelf: center ? "center" : "start" }}>{t("duo.archived")}</span>}
      </div>
    </div>
  );
}
