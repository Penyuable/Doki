import type { ZodTypeAny, z } from 'zod';
import { AppError } from './errors.js';

/** Parse dengan Zod; kegagalan menjadi AppError VALIDATION_ERROR. */
export function parse<S extends ZodTypeAny>(schema: S, data: unknown): z.infer<S> {
  const result = schema.safeParse(data);
  if (!result.success) {
    throw new AppError('VALIDATION_ERROR', 'Input tidak valid', {
      issues: result.error.issues.map((i) => ({
        path: i.path.join('.'),
        message: i.message,
        code: i.code,
      })),
    });
  }
  return result.data;
}
