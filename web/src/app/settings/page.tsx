'use client';

import { useRouter } from 'next/navigation';
import { useState, type ReactNode } from 'react';
import { Env } from '@/lib/config/env.ts';
import { TABLE_THEMES } from '@/lib/client/storage.ts';
import { LOCALES, languageName } from '@/lib/i18n/strings.ts';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { ConfirmDialog } from '@/components/ui/dialog';
import { Icon } from '@/components/ui/icon';
import { PageHead, Switch } from '@/components/ui/states';
import { useToast } from '@/components/ui/toast';

function Row({ title, hint, children }: { title: string; hint?: string; children: ReactNode }) {
  return (
    <div className="row" style={{ alignItems: 'center', padding: '6px 0' }}>
      <div className="grow">
        <b>{title}</b>
        {hint && <p className="muted small">{hint}</p>}
      </div>
      {children}
    </div>
  );
}

export default function SettingsPage() {
  const { t, settings, updateSettings, services, logout, resetOffline } = useApp();
  const router = useRouter();
  const toast = useToast();
  const [confirmReset, setConfirmReset] = useState(false);
  const [confirmLogout, setConfirmLogout] = useState(false);

  return (
    <main className="page" style={{ maxWidth: 720 }}>
      <PageHead title={t('settings.title')} back={() => router.back()} />

      <section className="clay card-pad stack">
        <b>{t('settings.language')}</b>
        <div className="segmented" role="group" aria-label={t('settings.language')}>
          {LOCALES.map((code) => (
            <button key={code} type="button" aria-pressed={settings.locale === code} onClick={() => updateSettings({ locale: code })}>
              {languageName(code)}
            </button>
          ))}
        </div>
        <p className="muted small">{t('settings.languageHint')}</p>
      </section>

      <section className="clay card-pad stack" style={{ gap: 4 }}>
        <Row title={t('settings.reduceMotion')} hint={t('settings.reduceMotionHint')}>
          <Switch label={t('settings.reduceMotion')} checked={settings.reduceMotion} onChange={(v) => updateSettings({ reduceMotion: v })} />
        </Row>
        <Row title={t('settings.batterySaver')} hint={t('settings.batterySaverHint')}>
          <Switch label={t('settings.batterySaver')} checked={settings.batterySaver} onChange={(v) => updateSettings({ batterySaver: v })} />
        </Row>
        <Row title={t('settings.haptics')} hint={t('settings.hapticsHint')}>
          <Switch label={t('settings.haptics')} checked={settings.haptics} onChange={(v) => updateSettings({ haptics: v })} />
        </Row>
        <Row title={t('settings.audio')} hint={t('settings.audioPending')}>
          <span className="pill">{t('settings.audioHint')}</span>
        </Row>
      </section>

      <section className="clay card-pad stack">
        <b>{t('table.title')}</b>
        <div className="row wrap">
          {TABLE_THEMES.map((theme) => (
            <button key={theme} type="button" className="chip" aria-pressed={settings.tableTheme === theme} onClick={() => updateSettings({ tableTheme: theme })}>
              {t(`table.${theme}`)}
            </button>
          ))}
        </div>
      </section>

      {services.offline ? (
        <section className="clay card-pad stack">
          <Row title={t('web.resetOffline')} hint={t('web.resetOfflineHint')}>
            <button type="button" className="btn small squish" data-tone="danger" onClick={() => setConfirmReset(true)}>
              <Icon name="trash" size={16} /> {t('common.delete')}
            </button>
          </Row>
        </section>
      ) : (
        <section className="clay card-pad stack">
          <Row title={t('settings.session')} hint={t('settings.sessionHint')}>
            <button type="button" className="btn small squish" data-tone="surface" onClick={() => setConfirmLogout(true)}>
              <Icon name="logout" size={16} /> {t('profile.logout')}
            </button>
          </Row>
        </section>
      )}

      <section className="clay card-pad stack" style={{ gap: 4 }}>
        <b>{t('settings.about')}</b>
        <p className="muted small">
          {t('app.name')} — {t('app.tagline')}
        </p>
        <p className="muted small">{t('profile.version', { version: Env.appVersion })}</p>
      </section>

      <ConfirmDialog
        open={confirmReset}
        title={t('web.resetOffline')}
        message={t('web.resetOfflineConfirm')}
        confirmLabel={t('common.delete')}
        tone="danger"
        onCancel={() => setConfirmReset(false)}
        onConfirm={() => {
          setConfirmReset(false);
          void resetOffline()
            .then(() => toast(t('web.resetDone')))
            .catch((error: unknown) => toast(errorMessage(error, t)));
        }}
      />
      <ConfirmDialog
        open={confirmLogout}
        title={t('auth.logout')}
        message={t('auth.logoutConfirm')}
        confirmLabel={t('auth.logout')}
        tone="danger"
        onCancel={() => setConfirmLogout(false)}
        onConfirm={() => {
          setConfirmLogout(false);
          void logout().catch((error: unknown) => toast(errorMessage(error, t)));
        }}
      />
    </main>
  );
}
