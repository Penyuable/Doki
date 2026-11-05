'use client';

import { useRouter } from 'next/navigation';
import { useMemo, useState } from 'react';
import { CARD_TYPES, ELEMENTS, RARITIES, elementSlug } from '@/lib/domain/card.ts';
import { playableCards } from '@/lib/data/repositories.ts';
import { COLLECTION_SORTS, DEFAULT_FILTER, applyCollectionFilter, isDefaultFilter, type CollectionFilter } from '@/lib/ui/collection.ts';
import { CardTile } from '@/components/cards/card-visuals';
import { useResource } from '@/components/hooks/use-resource';
import { useApp } from '@/components/providers/app-provider';
import { Icon } from '@/components/ui/icon';
import { EmptyState, ErrorState, Loading, PageHead } from '@/components/ui/states';

export default function CollectionPage() {
  const { t, services, catalog, user } = useApp();
  const router = useRouter();
  const [filter, setFilter] = useState<CollectionFilter>(DEFAULT_FILTER);
  const [more, setMore] = useState(false);
  const inventory = useResource(() => services.repos.inventory.load({ sort: 'rarity' }), [user?.id]);

  const owned = useMemo(() => new Map((inventory.data?.page.items ?? []).map((i) => [i.cardId, i.quantity])), [inventory.data]);
  const firstSeen = useMemo(
    () => new Map((inventory.data?.page.items ?? []).map((i) => [i.cardId, i.firstSeenAt])),
    [inventory.data],
  );
  const cards = useMemo(
    () => (catalog ? applyCollectionFilter(playableCards(catalog), filter, owned, firstSeen) : []),
    [catalog, filter, owned, firstSeen],
  );
  const set = (patch: Partial<CollectionFilter>) => setFilter((current) => ({ ...current, ...patch }));
  const totalPlayable = catalog ? playableCards(catalog).length : 0;

  return (
    <main className="page">
      <PageHead title={t('collection.title')}>
        <span className="pill">{t('collection.owned', { owned: owned.size, total: totalPlayable })}</span>
      </PageHead>

      {inventory.data?.offline && <p className="banner" data-tone="warning">{t('common.offline')}</p>}
      {catalog && catalog.source !== 'network' && <p className="banner">{t(`web.catalogSource.${catalog.source}`)}</p>}

      <div className="stack" style={{ gap: 10 }}>
        <div className="row">
          <label className="grow" style={{ position: 'relative' }}>
            <span className="sr-only">{t('common.search')}</span>
            <input
              className="input"
              type="search"
              value={filter.query}
              placeholder={t('collection.searchHint')}
              onChange={(event) => set({ query: event.target.value })}
            />
          </label>
          <button type="button" className="chip" aria-pressed={more} onClick={() => setMore(!more)} aria-expanded={more}>
            <Icon name="filter" size={18} /> {t('collection.moreFilters')}
          </button>
        </div>

        <div className="scroll-x" role="group" aria-label={t('collection.filterElement')}>
          <button type="button" className="chip" aria-pressed={filter.element === null} onClick={() => set({ element: null })}>
            {t('common.all')}
          </button>
          {ELEMENTS.map((element) => (
            <button key={element} type="button" className="chip" aria-pressed={filter.element === element} onClick={() => set({ element: filter.element === element ? null : element })}>
              {t(`element.${elementSlug(element)}`)}
            </button>
          ))}
        </div>

        {more && (
          <div className="clay card-pad stack">
            <div className="stack" style={{ gap: 6 }}>
              <span className="small" style={{ fontWeight: 800 }}>{t('collection.filterRarity')}</span>
              <div className="row wrap">
                {RARITIES.map((rarity) => (
                  <button key={rarity} type="button" className="chip" aria-pressed={filter.rarity === rarity} onClick={() => set({ rarity: filter.rarity === rarity ? null : rarity })}>
                    {t(`rarity.${rarity.toLowerCase()}`)}
                  </button>
                ))}
              </div>
            </div>
            <div className="stack" style={{ gap: 6 }}>
              <span className="small" style={{ fontWeight: 800 }}>{t('collection.filterType')}</span>
              <div className="row wrap">
                {CARD_TYPES.map((type) => (
                  <button key={type} type="button" className="chip" aria-pressed={filter.type === type} onClick={() => set({ type: filter.type === type ? null : type })}>
                    {t(`type.${type}`)}
                  </button>
                ))}
              </div>
            </div>
            <div className="stack" style={{ gap: 6 }}>
              <span className="small" style={{ fontWeight: 800 }}>{t('collection.filterOwnership')}</span>
              <div className="row wrap">
                {([
                  [null, 'common.all'],
                  [true, 'collection.ownedFilter'],
                  [false, 'collection.notOwnedFilter'],
                ] as const).map(([value, key]) => (
                  <button key={key} type="button" className="chip" aria-pressed={filter.ownedOnly === value} onClick={() => set({ ownedOnly: value })}>
                    {t(key)}
                  </button>
                ))}
              </div>
            </div>
            <div className="stack" style={{ gap: 6 }}>
              <span className="small" style={{ fontWeight: 800 }}>{t('collection.sort')}</span>
              <div className="row wrap">
                {COLLECTION_SORTS.map((sort) => (
                  <button key={sort} type="button" className="chip" aria-pressed={filter.sort === sort} onClick={() => set({ sort })}>
                    {t(`collection.sort.${sort}`)}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {!isDefaultFilter(filter) && (
          <div>
            <button type="button" className="btn-text" onClick={() => setFilter({ ...DEFAULT_FILTER, sort: filter.sort })}>
              {t('collection.reset')}
            </button>
          </div>
        )}
      </div>

      {inventory.status === 'loading' && !inventory.data ? (
        <Loading />
      ) : inventory.status === 'error' && !inventory.data ? (
        <ErrorState error={inventory.error} onRetry={() => void inventory.reload()} />
      ) : cards.length === 0 ? (
        <EmptyState icon="search" message={t('collection.empty')} />
      ) : (
        <div className="grid-cards">
          {cards.map((card) => (
            <CardTile
              key={card.id}
              card={card}
              quantity={owned.get(card.id) ?? 0}
              onClick={() => router.push(`/collection/card/?id=${encodeURIComponent(card.id)}`)}
            />
          ))}
        </div>
      )}
    </main>
  );
}
