'use client';

import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useState } from 'react';
import { CardArt, CardStats, ElementBadge, RarityPill } from '@/components/cards/card-visuals';
import { DeckPicker } from '@/components/cards/deck-picker';
import { MoveOrbRow } from '@/components/battle/skill-orb';
import { useResource } from '@/components/hooks/use-resource';
import { useApp } from '@/components/providers/app-provider';
import { Icon } from '@/components/ui/icon';
import { EmptyState, Loading, PageHead } from '@/components/ui/states';
import { elementSlug } from '@/lib/domain/card.ts';

function CardDetail() {
  const { t, catalog, services, user } = useApp();
  const router = useRouter();
  const id = useSearchParams().get('id') ?? '';
  const [picker, setPicker] = useState(false);
  const inventory = useResource(() => services.repos.inventory.load(), [user?.id]);
  const card = catalog?.byId.get(id) ?? null;

  if (!catalog) return <Loading />;
  if (!card) {
    return (
      <main className="page">
        <PageHead title={t('web.notFound')} back={() => router.back()} />
        <EmptyState icon="search" message={t('web.notFound')} action={<Link href="/collection/" className="btn small">{t('collection.title')}</Link>} />
      </main>
    );
  }

  const quantity = inventory.data?.page.items.find((item) => item.cardId === card.id)?.quantity ?? 0;
  const ability = card.ability;

  return (
    <main className="page">
      <PageHead title={card.name} back={() => router.back()}>
        <ElementBadge card={card} size={32} />
      </PageHead>
      <div className="two-col">
        <div className="stack">
          <div className="clay card-pad stack">
            <CardArt card={card} />
            <div className="row wrap">
              <RarityPill rarity={card.rarity} />
              <span className="pill">{t(`type.${card.type}`)}</span>
              <span className="pill" data-tone={`el-${elementSlug(card.element)}`}>
                {t(`element.${elementSlug(card.element)}`)}
              </span>
              <span className="pill" data-tone="accent">
                <Icon name="bolt" size={12} /> {t('card.cost')} {card.cost}
              </span>
              <span className="grow" />
              <span className="pill" data-tone={quantity > 0 ? 'success' : 'high'}>
                {quantity > 0 ? t('card.ownedCount', { count: quantity }) : t('card.notOwned')}
              </span>
            </div>
          </div>
        </div>

        <div className="stack">
          <CardStats card={card} />
          <section className="clay card-pad stack">
            <h2 className="section-title">{t('card.moves')}</h2>
            <MoveOrbRow card={card} />
          </section>
          {ability && (
            <section className="clay card-pad stack" style={{ gap: 6 }}>
              <div className="row">
                <h2 className="section-title grow">{t('card.ability')}</h2>
                <span className="pill">{t(`ability.${ability.type}`)}</span>
              </div>
              <b>{ability.name}</b>
              <p className="muted">{ability.text}</p>
              <span className="muted small">{t('card.abilityCost', { cost: ability.cost })}</span>
            </section>
          )}
          {card.keywords.length > 0 && (
            <section className="clay card-pad stack" style={{ gap: 8 }}>
              <h2 className="section-title">{t('card.keywords')}</h2>
              <div className="row wrap">
                {card.keywords.map((keyword) => (
                  <span key={keyword} className="pill" data-tone="primary">
                    {t(`keyword.${keyword}`)}
                  </span>
                ))}
              </div>
            </section>
          )}
          {card.flavorText && (
            <section className="clay card-pad stack" style={{ gap: 6 }}>
              <h2 className="section-title">{t('card.flavor')}</h2>
              <p className="muted" style={{ fontStyle: 'italic' }}>
                “{card.flavorText}”
              </p>
            </section>
          )}
          {quantity > 0 && (
            <button type="button" className="btn block squish" onClick={() => setPicker(true)}>
              <Icon name="plus" /> {t('card.addToDeck')}
            </button>
          )}
        </div>
      </div>

      <DeckPicker
        open={picker}
        onClose={() => setPicker(false)}
        onPick={(deckId) => {
          setPicker(false);
          const params = new URLSearchParams({ card: card.id });
          if (deckId) params.set('id', deckId);
          router.push(`/deck/edit/?${params.toString()}`);
        }}
      />
    </main>
  );
}

export default function CardDetailPage() {
  return (
    <Suspense fallback={<Loading />}>
      <CardDetail />
    </Suspense>
  );
}
