import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import { AppProvider } from '@/components/providers/app-provider';
import { ToastProvider } from '@/components/ui/toast';
import { AppShell } from '@/components/shell/app-shell';
import { translator } from '@/lib/i18n/strings.ts';
import './globals.css';
import './components.css';

// Teks statis prerender memakai locale default (id); runtime mengikuti pengaturan pemain.
const t = translator('id');

export const metadata: Metadata = {
  title: t('app.name'),
  description: t('auth.subtitle'),
  applicationName: t('app.name'),
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  themeColor: '#e9e7f7',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="id">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;700;800;900&display=swap" rel="stylesheet" />
      </head>
      <body>
        <noscript>
          <p style={{ padding: 24, textAlign: 'center' }}>{t('web.noJs')}</p>
        </noscript>
        <AppProvider>
          <ToastProvider>
            <AppShell>{children}</AppShell>
          </ToastProvider>
        </AppProvider>
      </body>
    </html>
  );
}
