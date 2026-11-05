'use client';

import { useState, type FormEvent } from 'react';
import { validEmail, validPassword, validUsername } from '@/lib/ui/auth-validation.ts';
import { Logo } from '@/components/shell/app-shell';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { Icon } from '@/components/ui/icon';

type Mode = 'login' | 'register';

/** Halaman masuk/daftar (mode server). Mode offline tidak pernah sampai ke sini. */
export default function LoginPage() {
  const { t, login, register, sessionExpired, status } = useApp();
  const [mode, setMode] = useState<Mode>('login');
  const [email, setEmail] = useState('');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [touched, setTouched] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const emailError = touched && !validEmail(email) ? t('auth.validationEmail') : null;
  const usernameError = touched && mode === 'register' && !validUsername(username) ? t('auth.validationUsername') : null;
  const passwordError = touched && !validPassword(password) ? t('auth.validationPassword') : null;

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setTouched(true);
    if (!validEmail(email) || !validPassword(password) || (mode === 'register' && !validUsername(username))) return;
    setBusy(true);
    setError(null);
    try {
      if (mode === 'login') await login(email, password);
      else await register(email, username, password);
    } catch (caught) {
      setError(errorMessage(caught, t));
    } finally {
      setBusy(false);
    }
  };

  return (
    <main className="splash">
      <form className="clay card-pad stack" style={{ width: 'min(420px, 100%)', textAlign: 'left', padding: 26 }} onSubmit={(e) => void submit(e)} noValidate>
        <div className="row">
          <Logo size={52} />
          <div>
            <h1 style={{ fontSize: 26, fontWeight: 900 }}>{t('app.name')}</h1>
            <p className="muted small">{mode === 'login' ? t('auth.welcomeBack') : t('auth.registerCta')}</p>
          </div>
        </div>
        <p className="muted small">{t('auth.subtitle')}</p>
        {sessionExpired && <p className="banner" data-tone="warning">{t('auth.sessionExpired')}</p>}
        {status === 'booting' && <p className="muted small">{t('common.loading')}</p>}

        <div className="field">
          <label htmlFor="email">{t('auth.email')}</label>
          <input id="email" className="input" type="email" autoComplete="email" placeholder={t('auth.hintEmail')} value={email} onChange={(e) => setEmail(e.target.value)} aria-invalid={!!emailError} />
          {emailError && <span className="field-error">{emailError}</span>}
        </div>
        {mode === 'register' && (
          <div className="field">
            <label htmlFor="username">{t('auth.username')}</label>
            <input id="username" className="input" autoComplete="username" placeholder={t('auth.hintUsername')} value={username} onChange={(e) => setUsername(e.target.value)} aria-invalid={!!usernameError} />
            {usernameError && <span className="field-error">{usernameError}</span>}
          </div>
        )}
        <div className="field">
          <label htmlFor="password">{t('auth.password')}</label>
          <input
            id="password"
            className="input"
            type="password"
            autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
            placeholder={t('auth.hintPassword')}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            aria-invalid={!!passwordError}
          />
          {passwordError && <span className="field-error">{passwordError}</span>}
        </div>

        {error && (
          <p className="banner" data-tone="danger" role="alert">
            {error}
          </p>
        )}

        <button type="submit" className="btn block squish" disabled={busy}>
          <Icon name={mode === 'login' ? 'user' : 'plus'} size={18} /> {mode === 'login' ? t('auth.loginCta') : t('auth.registerCta')}
        </button>
        <button
          type="button"
          className="btn-text"
          onClick={() => {
            setMode(mode === 'login' ? 'register' : 'login');
            setError(null);
            setTouched(false);
          }}
        >
          {mode === 'login' ? t('auth.toRegister') : t('auth.toLogin')}
        </button>
      </form>
    </main>
  );
}
