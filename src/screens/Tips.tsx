import { t } from "../i18n";
import { EmptyState } from "../components/ui";

/** Astuces : rubrique personnelle. Les 500 cartes attendent leur validation éditoriale (décision 11B). */
export function Tips() {
  return (
    <main className="page page--read">
      <div className="page-header">
        <h1 className="t-page">{t("tips.title")}</h1>
        <p>{t("tips.subtitle")}</p>
      </div>
      <EmptyState illustration="12-astuce" title={t("tips.soonTitle")} text={t("tips.soonText")} />
    </main>
  );
}
