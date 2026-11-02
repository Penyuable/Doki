export type ErrorCode =
  | 'VALIDATION_ERROR'
  | 'DECK_INVALID'
  | 'UNAUTHORIZED'
  | 'TOKEN_EXPIRED'
  | 'INVALID_CREDENTIALS'
  | 'REFRESH_REUSED'
  | 'INSUFFICIENT_FUNDS'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'DUPLICATE_EMAIL'
  | 'DUPLICATE_USERNAME'
  | 'DECK_NAME_TAKEN'
  | 'CARD_NOT_OWNED'
  | 'CATALOG_INVALID'
  | 'CATALOG_UNAVAILABLE'
  | 'RATE_LIMITED'
  | 'ALREADY_CLAIMED'
  | 'SUSPICIOUS_RESULT'
  | 'MATCH_ALREADY_REPORTED'
  | 'INTERNAL_ERROR';

const STATUS: Record<ErrorCode, number> = {
  VALIDATION_ERROR: 400,
  DECK_INVALID: 400,
  UNAUTHORIZED: 401,
  TOKEN_EXPIRED: 401,
  INVALID_CREDENTIALS: 401,
  REFRESH_REUSED: 401,
  INSUFFICIENT_FUNDS: 402,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  DUPLICATE_EMAIL: 409,
  DUPLICATE_USERNAME: 409,
  DECK_NAME_TAKEN: 409,
  CARD_NOT_OWNED: 409,
  CATALOG_INVALID: 422,
  CATALOG_UNAVAILABLE: 503,
  RATE_LIMITED: 429,
  ALREADY_CLAIMED: 409,
  SUSPICIOUS_RESULT: 422,
  MATCH_ALREADY_REPORTED: 409,
  INTERNAL_ERROR: 500,
};

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly details?: unknown;

  constructor(code: ErrorCode, message: string, details?: unknown) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.status = STATUS[code];
    this.details = details;
  }

  toJSON() {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.details !== undefined ? { details: this.details } : {}),
      },
    };
  }
}

export const unauthorized = (message = 'Autentikasi diperlukan') =>
  new AppError('UNAUTHORIZED', message);

export const notFound = (what = 'Resource') =>
  new AppError('NOT_FOUND', `${what} tidak ditemukan`);

export const invalid = (message: string, details?: unknown) =>
  new AppError('VALIDATION_ERROR', message, details);
