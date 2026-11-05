/**
 * JSON kanonik (port `core/utils/canonical_json.dart`): key objek diurutkan
 * rekursif, tanpa spasi. Dipakai untuk `logHash` battle.
 */
export function canonicalJson(value: unknown): string {
  if (value === null || value === undefined) return 'null';
  if (typeof value === 'number' || typeof value === 'boolean' || typeof value === 'string') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(',')}]`;
  }
  if (typeof value === 'object') {
    const map = value as Record<string, unknown>;
    const keys = Object.keys(map).sort();
    return `{${keys.map((key) => `${JSON.stringify(key)}:${canonicalJson(map[key])}`).join(',')}}`;
  }
  return JSON.stringify(String(value));
}
