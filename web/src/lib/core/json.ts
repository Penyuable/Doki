/**
 * Parsing JSON defensif (port `core/utils/json_utils.dart`).
 * Field dari network tidak pernah diasumsikan ada atau bertipe benar.
 */

export type JsonMap = Record<string, unknown>;

export function asMap(value: unknown): JsonMap {
  if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
    return value as JsonMap;
  }
  return {};
}

export function asList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

export function asString(value: unknown, fallback = ''): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return fallback;
}

export function asStringOrNull(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

export function asInt(value: unknown, fallback = 0): number {
  const parsed = asIntOrNull(value);
  return parsed ?? fallback;
}

export function asIntOrNull(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Number.isInteger(value) ? value : Math.round(value);
  }
  if (typeof value === 'string' && /^-?\d+$/.test(value.trim())) {
    return Number.parseInt(value.trim(), 10);
  }
  return null;
}

export function asNumber(value: unknown, fallback = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : fallback;
  }
  return fallback;
}

export function asBool(value: unknown, fallback = false): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const lower = value.toLowerCase();
    if (lower === 'true' || lower === '1') return true;
    if (lower === 'false' || lower === '0') return false;
  }
  return fallback;
}

export function asDate(value: unknown): Date | null {
  if (typeof value !== 'string') return null;
  const time = Date.parse(value);
  return Number.isNaN(time) ? null : new Date(time);
}

/** Nilai enum dari API (case-insensitive) dengan fallback. */
export function enumFrom<T extends string>(raw: unknown, values: readonly T[], fallback: T): T {
  const text = asString(raw).toLowerCase();
  if (!text) return fallback;
  return values.find((value) => value.toLowerCase() === text) ?? fallback;
}
