'use client';

import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useEffect, useMemo, useState } from 'react';
import { GameConfig } from '@/lib/config/game-config.ts';
import { ApiError } from '@/lib/data/api-client.ts';
import { playableCards } from '@/lib/data/repositories.ts';
import { ELEMENTS, elementSlug, type Card } from '@/lib/domain/card.ts';
import { canAddCard } from '@/lib/domain/deck-rules.ts';
import { deckEntries } from '@/lib/domain/models.ts';
import { DEFAULT_FILTER, applyCollectionFilter, type CollectionFilter } from '@/lib/ui/collection.ts';
import {
  addCard,
  curveBuckets,
  defaultDeckName,
  nameValid,
  removeCard,
  totalCards,
  validateDraft,
  type DeckDraft,
} from '@/lib/ui/deck-builder.ts';
import { CardTile } from '@/components/cards/card-visuals';
import { Creature } from '@/components/cards/creature';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { Icon } from '@/components/ui/icon';
import { ErrorState, Loading, PageHead, ProgressBar } from '@/components/ui/states';
import { useToast } from '@/components/ui/toast';

type LoadState =
  | { status: 'loading' }
  | { status: 'error'; error: unknown }
  | { status: 'ready'; owned: Map<string, number>; draft: DeckDraft };

function violationText(code: string, fallback: string, t: ReturnType<typeof useApp>['t']): string {
  const key = `deck.violation.${code}`;
  const text = t(key);
  return text === key ? fallback : text;
}

function DeckBuilder() {
  const { t, services, catalog, setActiveDeckId } = useApp();
  const router = useRouter();
  const toast = useToast();
  const params = useSearchParams();
  const deckId = params.get('id');
  const initialCardId = params.get('card');
  const [state, setState] = useState<LoadState>({ status: 'loading' });
  const [filter, setFilter] = useState<CollectionFilter>({ ...DEFAULT_FILTER, ownedOnly: true });
  const [saving, setSaving] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setState({ status: 'loading' });
    void (async () => {
      try {
        const inventory = await services.repos.inventory.load();
        const owned = new Map(inventory.page.items.map((item) => [item.cardId, item.quantity]));
        let draft: DeckDraft;
        if (deckId) {
          const deck = await services.repos.deck.get(deckId);
          draft = { deckId: deck.id, name: deck.name, entries: deckEntries(deck) };
        } else {
          const decks = await services.repos.deck.list();
          draft = { deckId: null, name: defaultDeckName(decks.map((d) => d.name)), entries: new Map() };
        }
        if (initialCardId) draft = addCard(draft, initialCardId, owned) ?? draft;
        if (!cancelled) setState({ status: 'ready', owned, draft });
      } catch (error) {
        if (!cancelled) setState({ status: 'error', error });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [services, deckId, initialCardId, nonce]);

  const ready = state.status === 'ready' ? state : null;
  const validation = useMemo(
    () => (ready && catalog ? validateDraft(ready.draft, ready.owned, catalog.byId) : null),
    [ready, catalog],
  );
  const pool = useMemo(
    () => (ready && catalog ? applyCollectionFilter(playableCards(catalog), filter, ready.owned) : []),
    [ready, catalog, filter],
  );

  if (state.status === 'loading' || !catalog) return <Loading />;
  if (state.status === 'error') return <main className="page"><ErrorState error={state.error} onRetry={() => setNonce((n) => n + 1)} /></main>;

  const { draft, owned } = state;
  const update = (next: DeckDraft) => {
    setState({ status: 'ready', owned, draft: next });
    setSaveError(null);
  };
  const total = totalCards(draft.entries);
  const selected = [...draft.entries.entries()]
    .map(([id, qty]) => ({ card: catalog.byId.get(id), qty }))
    .filter((row): row is { card: Card; qty: number } => !!row.card)
    .sort((a, b) => a.card.cost - b.card.cost || (a.card.name < b.card.name ? -1 : 1));
  const buckets = curveBuckets(validation?.curve ?? new Map());
  const peak = Math.max(1, ...buckets);

  const save = async () => {
    if (!validation?.canSave) {
      setSaveError(!nameValid(draft.name) ? t('deck.nameRequired') : t('deck.invalid'));
      return;
    }
    setSaving(true);
    setSaveError(null);
    try {
      const saved = draft.deckId
        ? await services.repos.deck.update(draft.deckId, draft.name.trim(), draft.entries)
        : await services.repos.deck.create(draft.name.trim(), draft.entries);
      if (saved.isActive) setActiveDeckId(saved.id);
      toast(t('deck.saved'));
      router.replace('/deck/');
    } catch (error) {
      if (error instanceof ApiError && error.code === 'DECK_NAME_TAKEN') setSaveError(t('deck.deckNameTaken'));
      else setSaveError(errorMessage(error, t));
    } finally {
      setSaving(false);
    }
  };

  return (
    <main className="page">
      <PageHead title={draft.deckId ? t('deck.edit') : t('deck.newTitle')} back={() => router.back()} />

      <div className="builder">
        <section className="stack" aria-label={t('deck.collection')}>
          <div className="scroll-x">
            <button type="button" className="chip" aria-pressed={filter.element === null} onClick={() => setFilter({ ...filter, element: null })}>
              {t('common.all')}
            </button>
            {ELEMENTS.map((element) => (
              <button key={element} type="button" className="chip" aria-pressed={filter.element === element} onClick={() => setFilter({ ...filter, element: filter.element === element ? null : element })}>
                {t(`element.${elementSlug(element)}`)}
              </button>
            ))}
          </div>
          <input className="input" type="search" placeholder={t('deck.searchHint')} value={filter.query} onChange={(e) => setFilter({ ...filter, query: e.target.value })} aria-label={t('common.search')} />
          <div className="grid-cards">
            {pool.map((card) => {
              const inDeck = draft.entries.get(card.id) ?? 0;
              const ownedCount = owned.get(card.id) ?? 0;
              const can = canAddCard({ entries: draft.entries, cardId: card.id, ownedCount });
              return (
                <CardTile
                  key={card.id}
                  card={card}
                  quantity={ownedCount}
                  selected={inDeck > 0}
                  onClick={can ? () => update(addCard(draft, card.id, owned) ?? draft) : undefined}
                  footer={
                    <div className="row" style={{ justifyContent: 'space-between' }}>
                      <span className="muted small">{t('deck.copyOf', { count: inDeck, max: Math.min(GameConfig.maxCopiesPerCard, ownedCount) })}</span>
                      {!can && inDeck === 0 && <span className="muted small">—</span>}
                    </div>
                  }
                />
              );
            })}
          </div>
        </section>

        <aside className="builder-side clay card-pad stack" aria-label={t('deck.selected')}>
          <div className="field">
            <label htmlFor="deck-name">{t('deck.name')}</label>
            <input id="deck-name" className="input" maxLength={24} value={draft.name} placeholder={t('deck.nameHint')} onChange={(e) => update({ ...draft, name: e.target.value })} />
            {!nameValid(draft.name) && <span className="field-error">{t('deck.nameRequired')}</span>}
          </div>

          <div className="row">
            <b className="grow">{t('deck.size', { count: total, max: GameConfig.deckSize })}</b>
            <span className="pill" data-tone={validation?.valid ? 'success' : 'warning'}>
              {validation?.valid ? t('deck.valid') : t('deck.invalid')}
            </span>
          </div>
          <ProgressBar value={total / GameConfig.deckSize} tone={total === GameConfig.deckSize ? 'success' : 'primary'} />

          <div className="stack" style={{ gap: 6 }}>
            <span className="small" style={{ fontWeight: 800 }}>{t('deck.curve')}</span>
            <div className="curve" aria-hidden>
              {buckets.map((count, cost) => (
                <div key={cost} className="curve-col">
                  <span style={{ height: `${(count / peak) * 70}px` }} />
                  <span>{cost === buckets.length - 1 ? `${cost}+` : cost}</span>
                </div>
              ))}
            </div>
          </div>

          {validation && validation.violations.filter((v) => v.code !== 'DECK_SIZE').length > 0 && (
            <ul className="stack" style={{ gap: 4, margin: 0, paddingLeft: 18 }}>
              {validation.violations
                .filter((v) => v.code !== 'DECK_SIZE')
                .map((v, i) => (
                  <li key={`${v.code}-${v.cardId ?? i}`} className="field-error">
                    {violationText(v.code, v.message, t)}
                    {v.cardId ? ` · ${catalog.byId.get(v.cardId)?.name ?? v.cardId}` : ''}
                  </li>
                ))}
            </ul>
          )}

          <div className="stack" style={{ gap: 2, maxHeight: 360, overflow: 'auto' }}>
            {selected.length === 0 && <p className="muted small">{t('deck.addCards')}</p>}
            {selected.map(({ card, qty }) => (
              <div key={card.id} className="deck-line">
                <span className={`mini-art el-bg-${elementSlug(card.element)}`}>
                  <Creature card={card} animate={false} />
                </span>
                <span className="grow small" style={{ fontWeight: 800 }}>
                  {card.name}
                  <span className="muted" style={{ display: 'block', fontWeight: 700 }}>
                    <Icon name="bolt" size={11} /> {card.cost}
                  </span>
                </span>
                <span className="qty-ctrl">
                  <button type="button" aria-label={`${t('common.delete')} ${card.name}`} onClick={() => update(removeCard(draft, card.id))}>
                    <Icon name="minus" size={16} />
                  </button>
                  <b style={{ minWidth: 18, textAlign: 'center' }}>{qty}</b>
                  <button
                    type="button"
                    aria-label={`${t('deck.addCards')} ${card.name}`}
                    disabled={!canAddCard({ entries: draft.entries, cardId: card.id, ownedCount: owned.get(card.id) ?? 0 })}
                    onClick={() => update(addCard(draft, card.id, owned) ?? draft)}
                  >
                    <Icon name="plus" size={16} />
                  </button>
                </span>
              </div>
            ))}
          </div>

          {saveError && <p className="field-error" role="alert">{saveError}</p>}
          <div className="row">
            <button type="button" className="btn-text" disabled={total === 0} onClick={() => update({ ...draft, entries: new Map() })}>
              {t('deck.clear')}
            </button>
            <button type="button" className="btn grow squish" disabled={saving} onClick={() => void save()}>
              <Icon name="check" /> {saving ? t('deck.saving') : t('deck.save')}
            </button>
          </div>
        </aside>
      </div>
    </main>
  );
}

export default function DeckBuilderPage() {
  return (
    <Suspense fallback={<Loading />}>
      <DeckBuilder />
    </Suspense>
  );
}
