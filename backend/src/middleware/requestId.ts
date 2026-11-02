import type { NextFunction, Request, Response } from 'express';
import crypto from 'node:crypto';

export function requestId(req: Request, res: Response, next: NextFunction) {
  const incoming = req.header('x-request-id');
  const id = incoming && incoming.length <= 64 ? incoming : `req_${crypto.randomUUID()}`;
  res.locals.requestId = id;
  res.setHeader('X-Request-Id', id);
  next();
}
