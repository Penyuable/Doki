'use client';

import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { GameConfig } from '@/lib/config/game-config.ts';
import { ApiError } from '@/lib/data/api-client.ts';
import { pityProgress, type GachaPullResponse } from '@/lib/domain/models.ts';
import { newIdempotencyKey } from '@/lib/client/services.ts';
import { rarityTone } from '@/components/cards/card-visuals';
import { GachaReveal } from '@/components/gacha/reveal';
import { useResource } from '@/components/hooks/use-resource';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { Dialog } from '@/components/ui/dialog';
import { Icon } from '@/components/ui/icon';
import { ErrorState, Loading, PageHead, ProgressBar } from '@/components/ui/states';
import { useToast } from '@/components/ui/toast';

type Count = 1 | 10;
type Currency = 'gold' | 'gem';

export default function GachaPage() {
  const { t, services, user, applyWallet, refreshMe } = useApp();
  const router = useRouter();
  const toast = useToast();
  const rates = useResource(() => services.repos.gacha.rates(), []);
  const pity = useResource(() => services.repos.gacha.pity(), [user?.id]);
  const history = useResource(() => services.repos.gacha.history(20), [user?.id]);
  const [pulling, setPulling] = useState(false);
  const [reveal, setReveal] = useState<GachaPullResponse | null>(null);
  const [ratesOpen, setRatesOpen] = useState(false);
  const [offerGem, setOfferGem] = useState<Count | null>(null);
  const [last, setLast] = useState<{ count: Count; currency: Currency }>({ count: 1, currency: 'gold' });

  if (!user) return null;

  // Harga hanya dipakai untuk label & pra-cek UI; server yang memotong saldo (I-01/I-06).
  const price = (count: Count, currency: Currency) => (currency === 'gold' ? GameConfig.gachaGoldPrice[count] : GameConfig.gachaGemPrice[count]);

  const pull = async (count: Count, currency: Currency) => {
    setLast({ count, currency });
    const balance = currency === 'gold' ? user.gold : user.gems;
    if (balance < price(count, currency)) {
      if (currency === 'gold') setOfferGem(count);
      else toast(t('gacha.insufficientGem'));
      return;
    }
    setPulling(true);
    try {
      const response = await services.repos.gacha.pull({ count, currency, idempotencyKey: newIdempotencyKey() });
      applyWallet(response.balance);
      pity.mutate(() => response.pity);
      setReveal(response);
      void history.reload(true);
      void refreshMe().catch(() => undefined);
    } catch (error) {
      if (error instanceof ApiError && error.isInsufficientFunds) {
        if (currency === 'gold') setOfferGem(count);
        else toast(t('gacha.insufficientGem'));
        void refreshMe().catch(() => undefined);
      } else {
        toast(errorMessage(error, t));
      }
    } finally {
      setPulling(false);
    }
  };

  const pityInfo = pity.data;

  return (
    <main className="page">
      <PageHead title={t('gacha.title')}>
        <button type="button" className="btn small squish" data-tone="surface" onClick={() => setRatesOpen(true)}>
          <Icon name="help" size={18} /> {t('gacha.rates')}
        </button>
      </PageHead>

      <section className="gacha-hero clay">
        <div className="gacha-orb" aria-hidden>
          <Icon name="gift" size={58} strokeWidth={1.8} />
        </div>
        <p className="pill" data-tone="primary" style={{ justifySelf: 'center' }}>
          {t('gacha.oddsTeaser')}
        </p>
        {pityInfo ? (
          <div className="stack" style={{ gap: 6, maxWidth: 420, width: '100%', justifySelf: 'center' }}>
            <div className="row">
              <b className="grow" style={{ textAlign: 'left' }}>
                {t('gacha.pityProgress', { current: pityInfo.counter, max: pityInfo.threshold })}
              </b>
              <span className="muted small">{t('gacha.pity', { count: pityInfo.guaranteedIn })}</span>
            </div>
            <ProgressBar value={pityProgress(pityInfo)} tone="r-epic" />
          </div>
        ) : pity.status === 'error' ? (
          <ErrorState error={pity.error} onRetry={() => void pity.reload()} />
        ) : (
          <Loading />
        )}

        <div className="two-col" style={{ gap: 12 }}>
          {([1, 10] as const).map((count) => (
            <div key={count} className="stack" style={{ gap: 8 }}>
              <b>{count === 1 ? t('gacha.pull1') : t('gacha.pull10')}</b>
              <div className="row">
                <button type="button" className="btn grow squish" data-tone="gold" disabled={pulling} onClick={() => void pull(count, 'gold')}>
                  <Icon name="coin" size={18} /> {t('gacha.costGold', { amount: price(count, 'gold') })}
                </button>
                <button type="button" className="btn grow squish" data-tone="gem" disabled={pulling} onClick={() => void pull(count, 'gem')}>
                  <Icon name="gem" size={18} /> {t('gacha.costGem', { amount: price(count, 'gem') })}
                </button>
              </div>
            </div>
          ))}
        </div>
        <p className="muted small">{t('gacha.guarantee')}</p>
      </section>

      <section className="clay card-pad stack" aria-labelledby="history-title">
        <h2 id="history-title" className="section-title">
          {t('gacha.history')}
        </h2>
        {history.status === 'loading' && !history.data ? (
          <Loading />
        ) : history.status === 'error' && !history.data ? (
          <ErrorState error={history.error} onRetry={() => void history.reload()} />
        ) : (history.data ?? []).length === 0 ? (
          <p className="muted small">{t('web.history.empty')}</p>
        ) : (
          <div className="stack" style={{ gap: 4 }}>
            {(history.data ?? []).map((entry) => (
              <div key={entry.id} className="deck-line">
                <span className="rarity-dot" data-tone={rarityTone(entry.rarity)} />
                <span className="grow" style={{ fontWeight: 800 }}>
                  {entry.card?.name ?? entry.cardId}
                </span>
                {entry.isNew && <span className="pill" data-tone="success">{t('gacha.new')}</span>}
                <span className="pill" data-tone={rarityTone(entry.rarity)}>
                  {t(`rarity.${entry.rarity.toLowerCase()}`)}
                </span>
              </div>
            ))}
          </div>
        )}
      </section>

      <Dialog open={ratesOpen} onClose={() => setRatesOpen(false)} title={t('gacha.ratesTitle')} actions={<button type="button" className="btn small" onClick={() => setRatesOpen(false)}>{t('common.close')}</button>}>
        {rates.status === 'ready' ? (
          <div className="stack" style={{ gap: 8 }}>
            {rates.data.rates.map((rate) => (
              <div key={rate.rarity} className="row">
                <span className="rarity-dot" data-tone={rarityTone(rate.rarity)} />
                <span className="grow" style={{ fontWeight: 800 }}>
                  {t(`rarity.${rate.rarity.toLowerCase()}`)}
                </span>
                <b>{rate.percent}%</b>
              </div>
            ))}
            <p className="muted small" style={{ marginTop: 8 }}>
              {t('gacha.pityNote', { count: rates.data.pity.threshold - 1 })}
            </p>
            {rates.data.guaranteedRarePlusOnTen && <p className="muted small">{t('gacha.guarantee')}</p>}
          </div>
        ) : rates.status === 'error' ? (
          <ErrorState error={rates.error} onRetry={() => void rates.reload()} />
        ) : (
          <Loading />
        )}
      </Dialog>

      <Dialog
        open={offerGem !== null}
        onClose={() => setOfferGem(null)}
        title={t('gacha.notEnoughTitle')}
        actions={
          <>
            <button type="button" className="btn-text" onClick={() => setOfferGem(null)}>
              {t('common.cancel')}
            </button>
            <button
              type="button"
              className="btn small squish"
              data-tone="gem"
              onClick={() => {
                const count = offerGem ?? 1;
                setOfferGem(null);
                void pull(count, 'gem');
              }}
            >
              {t('gacha.useGem')}
            </button>
          </>
        }
      >
        <p className="muted">{t('gacha.insufficientBody', { price: t('gacha.costGold', { amount: price(offerGem ?? 1, 'gold') }) })}</p>
      </Dialog>

      <GachaReveal
        response={reveal}
        onClose={() => setReveal(null)}
        onPullAgain={() => {
          setReveal(null);
          void pull(last.count, last.currency);
        }}
        onViewCollection={() => {
          setReveal(null);
          router.push('/collection/');
        }}
      />
    </main>
  );
}
