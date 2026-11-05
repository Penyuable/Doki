/** Validasi form auth sisi klien (sama dengan auth_page.dart & backend auth.schema.ts). */
export const validEmail = (value: string): boolean => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value.trim());
export const validUsername = (value: string): boolean => /^[A-Za-z0-9_]{3,16}$/.test(value.trim());
export const validPassword = (value: string): boolean => value.length >= 8 && value.length <= 72;
