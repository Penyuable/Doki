import type { NextFunction, Request, Response } from 'express';
import { ZodError } from 'zod';
import { AppError } from '../lib/errors.js';
import { logger } from '../lib/logger.js';

export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({
    error: { code: 'NOT_FOUND', message: `Endpoint ${req.method} ${req.path} tidak ditemukan` },
    meta: { requestId: res.locals.requestId },
  });
}

export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
) {
  const requestId = res.locals.requestId as string | undefined;

  if (err instanceof AppError) {
    res.status(err.status).json({
      ...err.toJSON(),
      meta: { requestId },
    });
    return;
  }

  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Input tidak valid',
        details: { issues: err.issues.map((i) => ({ path: i.path.join('.'), message: i.message })) },
      },
      meta: { requestId },
    });
    return;
  }

  const anyErr = err as { type?: string; status?: number; message?: string };
  if (anyErr?.type === 'entity.parse.failed') {
    res.status(400).json({
      error: { code: 'VALIDATION_ERROR', message: 'Body JSON tidak valid' },
      meta: { requestId },
    });
    return;
  }

  logger.error('unhandled error', {
    requestId,
    method: req.method,
    path: req.path,
    message: anyErr?.message,
  });

  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: 'Terjadi kesalahan internal' },
    meta: { requestId },
  });
}
