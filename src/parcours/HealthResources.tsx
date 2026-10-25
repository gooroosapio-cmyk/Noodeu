import { Link } from "react-router";
import { t } from "../i18n";
import { useAuth } from "../auth/AuthProvider";
import { Icon } from "../components/ui";

/**
 * Ressources institutionnelles sur la santé sexuelle et le dépistage, par pays.
 * Chaque entrée est publiée par un organisme public (ou relayée par lui) ; vérifiées le 24/10/2026 par recherche web
 * (pages non ouvertes directement depuis l'environnement de développement) : à revérifier avant chaque mise à jour.
 */
interface Resource { name: string; detail: string; url?: string; phone?: string; source: string }
const RESOURCES: Record<string, Resource[]> = {
  FR: [
    { name: "Sida Info Service", detail: "Écoute et information sur le VIH, les IST et le dépistage : gratuit, anonyme, 24 h/24.", phone: "0 800 840 800",
      source: "Numéro relayé par la Ville de Paris et les agences régionales de santé" },
    { name: "Où se faire dépister gratuitement", detail: "Carte des lieux de dépistage gratuits.", url: "https://www.sante.fr/ou-se-faire-depister-gratuitement",
      source: "Sante.fr, service public d'information en santé" },
    { name: "QuestionSexualite.fr", detail: "Informations sur la sexualité, la contraception et les IST.", url: "https://www.questionsexualite.fr",
      source: "Santé publique France" },
  ],
  CH: [
    { name: "Centres de dépistage du VIH et d'autres IST", detail: "Liste des centres de dépistage en Suisse.",
      url: "https://www.bag.admin.ch/fr/centres-de-depistage-pour-le-vih-et-dautres-ist", source: "Office fédéral de la santé publique (OFSP)" },
    { name: "Infections sexuellement transmissibles", detail: "Prévention, symptômes et dépistage.",
      url: "https://www.bag.admin.ch/fr/infections-sexuellement-transmissibles", source: "Office fédéral de la santé publique (OFSP)" },
    { name: "LOVE LIFE", detail: "Campagne nationale de prévention et test de risque en ligne.", url: "https://lovelife.ch", source: "Campagne de l'OFSP" },
  ],
  CA: [
    { name: "Votre santé sexuelle est importante", detail: "Informations sur les infections transmissibles sexuellement et le dépistage.",
      url: "https://www.canada.ca/fr/services/sante/campagnes/infections-transmissibles-sexuellement.html", source: "Gouvernement du Canada" },
    { name: "Santé sexuelle", detail: "Ressources de l'Agence de la santé publique du Canada.",
      url: "https://www.canada.ca/fr/sante-publique/services/sante-sexuelle.html", source: "Agence de la santé publique du Canada" },
  ],
};

export function HealthResources() {
  const { profile } = useAuth();
  const country = profile?.country ?? null;
  const list = country ? RESOURCES[country] : null;
  return (
    <section className="card stack stack--4 health-resources" aria-labelledby="health-title">
      <h2 className="t-card row" id="health-title"><Icon name="shield-check" size={20} />{t("health.title")}</h2>
      {!country ? (
        <p className="t-small">{t("health.noCountry")} <Link to="/reglages">{t("health.setCountry")}</Link></p>
      ) : !list ? (
        <p className="t-small">{t("health.missing")}</p>
      ) : (
        <ul className="stack stack--3 plain-list">
          {list.map((r) => (
            <li key={r.name} className="stack" style={{ gap: 2 }}>
              <span className="t-card">{r.url ? <a href={r.url} target="_blank" rel="noopener noreferrer">{r.name}</a> : r.name}</span>
              <span className="t-small">{r.detail}</span>
              {r.phone && <a className="t-small strong" href={`tel:${r.phone.replace(/\s/g, "")}`}>{r.phone}</a>}
              <span className="t-meta">{t("health.source", { source: r.source })}</span>
            </li>
          ))}
        </ul>
      )}
      <p className="t-meta">{t("health.disclaimer")}</p>
    </section>
  );
}
