/**
 * Lokalisasi ringan tanpa codegen (port `core/i18n/app_strings.dart`).
 * Semua teks UI wajib lewat `t()`; `id` default, `en` opsional.
 */
import { BASE_STRINGS } from './base-strings.ts';
import { WEB_STRINGS } from './web-strings.ts';

export const LOCALES = ['id', 'en'] as const;
export type Locale = (typeof LOCALES)[number];

const TABLE: Record<Locale, Record<string, string>> = {
  id: { ...BASE_STRINGS.id, ...WEB_STRINGS.id },
  en: { ...BASE_STRINGS.en, ...WEB_STRINGS.en },
};

export type StringKey = keyof typeof BASE_STRINGS.id | keyof typeof WEB_STRINGS.id;
export type Translator = (key: StringKey | (string & {}), args?: Record<string, string | number>) => string;

export function translator(locale: Locale): Translator {
  const table = TABLE[locale] ?? TABLE.id;
  return (key, args) => {
    let text = table[key] ?? TABLE.id[key] ?? key;
    if (args) {
      for (const [name, value] of Object.entries(args)) text = text.split(`{${name}}`).join(String(value));
    }
    return text;
  };
}

export const hasKey = (locale: Locale, key: string): boolean => key in TABLE[locale];

export const allKeys = (locale: Locale): string[] => Object.keys(TABLE[locale]);

export const languageName = (locale: Locale): string => (locale === 'en' ? 'English' : 'Bahasa Indonesia');

export const isLocale = (value: unknown): value is Locale => value === 'id' || value === 'en';
