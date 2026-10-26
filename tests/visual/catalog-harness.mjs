// Montage des vrais hooks React pour les scénarios catalogue, sans démarrer l'application.
import { createElement } from 'react';
import { createRoot } from 'react-dom/client';
import { useCatalog } from '../../src/screens/catalog.ts';

function Consumer({ name, userId }) {
  const catalog = useCatalog(userId);
  const toggle = async gameId => {
    const ok = await catalog.toggleFavorite(gameId);
    window.catalogWrites.push({ name, userId, gameId, ok });
  };
  return createElement('section', { 'data-consumer': name },
    createElement('output', null, JSON.stringify({ userId, favorites: [...catalog.favorites].sort(), loading: catalog.loading, error: catalog.error })),
    createElement('button', { onClick: () => void toggle('game-one'), 'data-action': 'one' }, 'Favori un'),
    createElement('button', { onClick: () => void toggle('game-two'), 'data-action': 'two' }, 'Favori deux'),
    createElement('button', { onClick: async () => { await catalog.reload(); window.catalogReloads += 1; }, 'data-action': 'reload' }, 'Relire'),
  );
}

const root = createRoot(document.getElementById('root'));
window.catalogWrites = [];
window.catalogReloads = 0;
window.catalogHarness = {
  render(consumers) {
    root.render(createElement('main', null, consumers.map(({ name, userId }) => createElement(Consumer, { key: name, name, userId }))));
  },
};
