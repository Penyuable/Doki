'use client';

import { createContext, useCallback, useContext, useRef, useState, type ReactNode } from 'react';

type Toast = { id: number; message: string };
const ToastContext = createContext<(message: string, durationMs?: number) => void>(() => {});

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextId = useRef(1);

  const show = useCallback((message: string, durationMs = 2400) => {
    const id = nextId.current++;
    // Satu toast aktif seperti `hideCurrentSnackBar()` di Flutter.
    setToasts([{ id, message }]);
    window.setTimeout(() => setToasts((current) => current.filter((toast) => toast.id !== id)), durationMs);
  }, []);

  return (
    <ToastContext.Provider value={show}>
      {children}
      <div className="toasts" role="status" aria-live="polite">
        {toasts.map((toast) => (
          <div key={toast.id} className="toast">
            {toast.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export const useToast = () => useContext(ToastContext);
