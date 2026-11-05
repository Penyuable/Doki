'use client';

import type { ReactNode } from 'react';
import { errorMessage, useApp } from '../providers/app-provider';
import { Icon } from './icon';

export function Loading({ label }: { label?: string }) {
  const { t } = useApp();
  return (
    <div className="center-box" role="status">
      <div className="spinner" aria-hidden />
      <span className="muted">{label ?? t('common.loading')}</span>
    </div>
  );
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const { t } = useApp();
  return (
    <div className="center-box clay" role="alert">
      <Icon name="close" size={36} />
      <p style={{ fontWeight: 800 }}>{t('common.error')}</p>
      <p className="muted small">{errorMessage(error, t)}</p>
      {onRetry && (
        <button type="button" className="btn small squish" onClick={onRetry}>
          <Icon name="refresh" size={18} /> {t('common.retry')}
        </button>
      )}
    </div>
  );
}

export function EmptyState({ icon = 'cards', message, action }: { icon?: Parameters<typeof Icon>[0]['name']; message: string; action?: ReactNode }) {
  return (
    <div className="center-box clay">
      <span className="logo clay pressed" style={{ width: 64, height: 64 }}>
        <Icon name={icon} size={30} />
      </span>
      <p className="muted">{message}</p>
      {action}
    </div>
  );
}

export function PageHead({ title, back, children }: { title: string; back?: () => void; children?: ReactNode }) {
  const { t } = useApp();
  return (
    <div className="page-head">
      {back && (
        <button type="button" className="icon-btn" aria-label={t('common.back')} onClick={back}>
          <Icon name="back" />
        </button>
      )}
      <h1>{title}</h1>
      {children}
    </div>
  );
}

export function ProgressBar({ value, tone = 'primary', label }: { value: number; tone?: string; label?: string }) {
  const pct = Math.round(Math.min(1, Math.max(0, value)) * 100);
  return (
    <div className="bar" data-tone={tone} role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} aria-label={label}>
      <span style={{ width: `${pct}%` }} />
    </div>
  );
}

export function Switch({ checked, onChange, label }: { checked: boolean; onChange: (value: boolean) => void; label: string }) {
  return <button type="button" role="switch" aria-checked={checked} aria-label={label} className="switch" onClick={() => onChange(!checked)} />;
}
