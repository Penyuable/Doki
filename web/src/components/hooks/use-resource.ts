'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

/** State async eksplisit (setara sealed state Cubit: loading / ready / error). */
export type Resource<T> =
  | { status: 'loading'; data: T | null; error: null }
  | { status: 'ready'; data: T; error: null }
  | { status: 'error'; data: T | null; error: unknown };

export function useResource<T>(load: () => Promise<T>, deps: readonly unknown[], enabled = true) {
  const [state, setState] = useState<Resource<T>>({ status: 'loading', data: null, error: null });
  const loadRef = useRef(load);
  loadRef.current = load;
  const run = useRef(0);

  const reload = useCallback(async (silent = false) => {
    const id = ++run.current;
    if (!silent) setState((current) => ({ status: 'loading', data: current.data, error: null }));
    try {
      const data = await loadRef.current();
      if (id === run.current) setState({ status: 'ready', data, error: null });
    } catch (error) {
      if (id === run.current) setState((current) => ({ status: 'error', data: current.data, error }));
    }
  }, []);

  useEffect(() => {
    if (enabled) void reload();
    // `deps` sengaja disebar: pemanggil menentukan kapan data dimuat ulang.
  }, [enabled, reload, ...deps]);

  const mutate = useCallback((update: (current: T) => T) => {
    setState((current) => (current.data === null ? current : { status: 'ready', data: update(current.data), error: null }));
  }, []);

  return { ...state, reload, mutate };
}
