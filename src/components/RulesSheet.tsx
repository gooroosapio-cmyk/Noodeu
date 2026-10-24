import { t } from "../i18n";
import type { GameRules } from "../lib/types";
import { Icon, Sheet } from "./ui";

/** Règles d'une activité dans une fenêtre basse : consulter les règles ne quitte ni la fiche ni la partie. */
export function RulesSheet({ title, rules, extra, onClose }: { title: string; rules: GameRules; extra?: string; onClose: () => void }) {
  return (
    <Sheet title={<h2 className="t-section">{t("rules.title", { title })}</h2>} onClose={onClose}>
      {rules.objective && <p className="strong">{rules.objective}</p>}
      <ol className="how">{rules.how_to.map((x) => <li key={x}>{x}</li>)}</ol>
      <p className="row t-small"><Icon name="lock-keyhole" size={18} />{rules.privacy}</p>
      {extra && <p className="row t-small"><Icon name="lock-keyhole" size={18} />{extra}</p>}
      {rules.details.length > 0 && (
        <section className="stack stack--2">
          <h3 className="t-card">{t("rules.details")}</h3>
          <ul className="rules-details">{rules.details.map((x) => <li key={x}>{x}</li>)}</ul>
        </section>
      )}
    </Sheet>
  );
}
