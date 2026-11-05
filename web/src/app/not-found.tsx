'use client';

import Link from 'next/link';
import { useApp } from '@/components/providers/app-provider';
import { EmptyState } from '@/components/ui/states';

export default function NotFound() {
  const { t } = useApp();
  return (
    <main className="page">
      <EmptyState
        icon="search"
        message={t('web.notFound')}
        action={
          <Link href="/" className="btn small">
            {t('web.backHome')}
          </Link>
        }
      />
    </main>
  );
}
