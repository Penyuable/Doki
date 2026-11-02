import { z } from 'zod';

export const emailSchema = z
  .string()
  .trim()
  .email('Email tidak valid')
  .max(254)
  .transform((v) => v.toLowerCase());

export const usernameSchema = z
  .string()
  .trim()
  .regex(/^[a-zA-Z0-9_]{3,16}$/, 'Username 3–16 karakter: huruf, angka, underscore');

export const passwordSchema = z
  .string()
  .min(8, 'Password minimal 8 karakter')
  .max(72, 'Password maksimal 72 karakter');

export const registerSchema = z
  .object({
    email: emailSchema,
    username: usernameSchema,
    password: passwordSchema,
  })
  .strict();

export const loginSchema = z
  .object({
    email: emailSchema,
    password: z.string().min(1).max(72),
  })
  .strict();

export const refreshSchema = z
  .object({
    refreshToken: z.string().min(20).max(200),
  })
  .strict();

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
